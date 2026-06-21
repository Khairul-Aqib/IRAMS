import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_firestore_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }

  static final AuthService instance = AuthService._();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<void> login(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Account audit — record the sign-in. Helper swallows its own errors so
    // a Firestore hiccup can't block the login.
    await UserFirestoreService.instance.touchLastLogin();
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    UserFirestoreService.instance.clearCache();
    await FirebaseAuth.instance.signOut();
  }

  Future<bool> hasMfaEnrolled() async {
    final u = currentUser;
    if (u == null) return false;
    try {
      final factors = await u.multiFactor.getEnrolledFactors();
      return factors.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
