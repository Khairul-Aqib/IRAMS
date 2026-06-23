import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firestore_service.dart';

/// Thrown when a login attempt requires MFA verification to complete.
/// The UI must extract the [resolver] to send an SMS code and finish sign-in.
class MfaRequiredException implements Exception {
  final MultiFactorResolver resolver;
  MfaRequiredException(this.resolver);
}

class AuthService extends ChangeNotifier {
  AuthService._() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      if (!_suppressNotify) notifyListeners();
    });
  }

  static final AuthService instance = AuthService._();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// When true, auth-state-change events do NOT trigger [notifyListeners].
  /// Used during registration so the GoRouter redirect chain does not fire
  /// before the Firestore contractor profile has been fully written.
  bool _suppressNotify = false;

  /// Session-level flag: when true the router guard treats MFA as satisfied.
  /// Set by MfaGatePage on successful verification or user skip.
  /// Reset on logout so a fresh login re-evaluates MFA.
  bool mfaBypassed = false;

  // Single reusable instance — avoids creating a new GoogleSignIn each call.
  static final _googleSignIn = GoogleSignIn();

  /// Signs in with email/password. If the account has MFA enrolled, Firebase
  /// will NOT complete the sign-in — instead it throws
  /// [FirebaseAuthMultiFactorException]. We catch that and re-throw a
  /// [MfaRequiredException] so the UI can prompt for an OTP code.
  Future<void> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthMultiFactorException catch (e) {
      throw MfaRequiredException(e.resolver);
    }
  }

  /// Completes an MFA-gated sign-in using the OTP the user received.
  /// Called after [login] threw [MfaRequiredException].
  Future<void> completeMfaSignIn({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    // Suppress auth-state notifications until mfaBypassed is set, so the
    // router doesn't redirect to /mfa between sign-in and flag update.
    _suppressNotify = true;
    try {
      await resolver.resolveSignIn(assertion);
      mfaBypassed = true;
    } finally {
      _suppressNotify = false;
      notifyListeners();
    }
  }

  /// Creates a Firebase Auth user AND writes the Contractor Firestore profile
  /// in one atomic block with auth-state notifications suppressed. This prevents
  /// GoRouter from redirecting to the MFA gate before the profile (and phone
  /// number) has been persisted.
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String companyName,
    required String companyContactPhone,
    required String location,
    required List<String> serviceTypes,
  }) async {
    _suppressNotify = true;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Registration failed: user not created');

      // Write the full profile (including phone) BEFORE listeners fire.
      await FirestoreService.instance.upsertContractorProfileAdminFormat(
        contractorId: user.uid,
        fullName: fullName,
        email: email.trim().toLowerCase(),
        phoneNumber: phoneNumber,
        companyName: companyName,
        companyContactPhone: companyContactPhone,
        location: location,
        serviceTypes: serviceTypes,
      );

      // Email verification removed — SMS 2FA is the identity check.
    } finally {
      _suppressNotify = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    mfaBypassed = false;
    await FirebaseAuth.instance.signOut();
  }

  /// Triggers the native Google Sign-In picker and signs the user into Firebase.
  /// On the user's first sign-in a default contractor document is created so
  /// the app never reads a missing profile.  Returns without signing in if the
  /// user dismisses the picker.
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // user dismissed the picker

    final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } catch (e) {
      throw Exception('Google Sign-In failed: Unable to retrieve authentication tokens. $e');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Google Sign-In failed: No user returned.');
    }

    // Create a default contractor profile on first-ever sign-in.
    // We check existence first so that RegistrationDate is never overwritten.
    final docSnap =
        await FirestoreService.instance.contractors.doc(user.uid).get();
    if (!docSnap.exists) {
      await FirestoreService.instance.upsertContractorProfileAdminFormat(
        contractorId: user.uid,
        fullName: user.displayName ?? 'Google User',
        email: user.email ?? 'no-email@placeholder.irams',
        phoneNumber: '',
        companyName: 'Self-Employed',
        companyContactPhone: '',
        location: '',
        serviceTypes: [],
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final isPasswordUser =
        user.providerData.any((p) => p.providerId == 'password');
    if (!isPasswordUser) {
      throw Exception(
          'Password change is not available for Google Sign-In accounts');
    }

    // Re-authenticate first
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<bool> hasMfaEnrolled() async {
    if (mfaBypassed) return true;
    final u = currentUser;
    if (u == null) return false;

    // Refresh the user's Firebase Auth profile so provider data and
    // MFA factors reflect the server state. Critical after hot restart
    // or app resume where the cached User object can be stale.
    try {
      await u.reload();
    } catch (_) {
      // Non-fatal — proceed with cached state
    }

    // Re-read currentUser after reload — some platforms update the
    // internal reference rather than mutating the existing object.
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null) return false;

    // 1. Check Firebase Auth MFA factors (multiFactor.enroll path)
    try {
      final factors = await refreshed.multiFactor.getEnrolledFactors();
      if (factors.isNotEmpty) {
        mfaBypassed = true; // cache for rest of session
        return true;
      }
    } catch (_) {
      // Fall through to next check
    }

    // 2. Check if phone provider is linked. The MFA gate page uses
    //    linkWithCredential (not multiFactor.enroll), so enrolledFactors
    //    stays empty but the phone provider appears in providerData.
    if (refreshed.providerData.any((p) => p.providerId == 'phone')) {
      mfaBypassed = true;
      return true;
    }

    // 3. Fallback: check Firestore Is2FAEnabled field for cases where
    //    the above checks fail (e.g. provider data not yet propagated).
    try {
      final docId = await FirestoreService.instance.getMyContractorDocId();
      if (docId != null) {
        final doc =
            await FirestoreService.instance.contractors.doc(docId).get();
        final data = doc.data();
        if (data != null && data['Is2FAEnabled'] == true) {
          mfaBypassed = true;
          return true;
        }
      }
    } catch (_) {
      // If Firestore check also fails, fall through to false
    }

    return false;
  }

  /// Sets AccountStatus to 'deactivated' in Firestore (reversible by admin).
  /// Does NOT sign the user out or delete the Firebase Auth account.
  Future<void> deactivateAccount() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await FirestoreService.instance.contractors.doc(uid).update({
      'AccountStatus': 'deactivated',
    });
    await logout();
  }

  /// Permanently deletes the Firebase Auth account.
  /// Requires re-authentication first for password users.
  /// Also sets AccountStatus to 'deleted' in Firestore before deleting auth user.
  /// Soft-deletes the account: marks IsDeleted + Deactivated in Firestore,
  /// then signs out. The Firebase Auth user is preserved so job history
  /// and accounting records remain intact. Reactivation requires Admin action.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    await FirestoreService.instance.contractors.doc(user.uid).update({
      'IsDeleted': true,
      'AccountStatus': 'Deactivated',
    });

    await logout();
    // Auth state change triggers GoRouter redirect to /login automatically
  }
}
