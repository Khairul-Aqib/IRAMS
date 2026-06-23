import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../services/auth_service.dart';
import '../../../core/theme.dart';
import 'forgot_password_page.dart';

// Re-export so it's available if needed elsewhere, but mainly for the catch below.
export '../../../services/auth_service.dart' show MfaRequiredException;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _loadingGoogle = false;
  bool _obscurePassword = true;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loadingGoogle = true;
      _err = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;

      // currentUser is null when the user dismissed the picker — do nothing.
      if (AuthService.instance.currentUser == null) return;

      final hasMfa = await AuthService.instance.hasMfaEnrolled();
      if (!mounted) return;
      context.go(hasMfa ? '/' : '/mfa');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Google sign-in failed: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await AuthService.instance.login(_email.text, _pass.text);

      // Login succeeded without MFA challenge — check enrollment status.
      final hasMfa = await AuthService.instance.hasMfaEnrolled();
      if (!hasMfa) {
        if (mounted) context.go('/mfa');
      } else {
        if (mounted) context.go('/');
      }
    } on MfaRequiredException catch (e) {
      // User has MFA enrolled — Firebase halted sign-in pending OTP.
      if (!mounted) return;
      setState(() => _loading = false);
      await _handleMfaChallenge(e.resolver);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _err = switch (e.code) {
          'user-not-found' => 'No account found with this email',
          'wrong-password' => 'Incorrect password',
          'invalid-email' => 'Invalid email format',
          'user-disabled' => 'This account has been disabled',
          'too-many-requests' => 'Too many failed attempts. Try again later',
          'invalid-credential' => 'Invalid email or password',
          _ => 'Login failed: ${e.message}',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── MFA challenge flow ──────────────────────────────────────────────────

  Future<void> _handleMfaChallenge(MultiFactorResolver resolver) async {
    // Find the enrolled phone factor
    final phoneHint = resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;
    if (phoneHint == null) {
      setState(() => _err = 'No phone factor enrolled. Contact support.');
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: resolver.session,
        multiFactorInfo: phoneHint,
        verificationCompleted: (credential) async {
          // Auto-resolution (Android) — complete sign-in immediately
          try {
            final assertion =
                PhoneMultiFactorGenerator.getAssertion(credential);
            await resolver.resolveSignIn(assertion);
            AuthService.instance.mfaBypassed = true;
            if (mounted) context.go('/');
          } catch (e) {
            if (mounted) setState(() => _err = 'Auto-verification failed: $e');
          }
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _err = e.message ?? 'SMS verification failed (${e.code})';
          });
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() => _loading = false);
          _showMfaOtpDialog(
            resolver: resolver,
            verificationId: verificationId,
            phoneDisplay: phoneHint.phoneNumber,
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _err = 'Could not send verification code: $e';
        });
      }
    }
  }

  Future<void> _showMfaOtpDialog({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String phoneDisplay,
  }) async {
    final codeController = TextEditingController();
    bool verifying = false;
    String? dialogErr;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Verify Your Identity',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter the 6-digit code sent to $phoneDisplay',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '------',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        letterSpacing: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: kYellow, width: 1.5),
                      ),
                    ),
                  ),
                  if (dialogErr != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogErr!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: verifying ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDialogState(
                                () => dialogErr = 'Enter a 6-digit code');
                            return;
                          }

                          setDialogState(() {
                            verifying = true;
                            dialogErr = null;
                          });

                          try {
                            await AuthService.instance.completeMfaSignIn(
                              resolver: resolver,
                              verificationId: verificationId,
                              smsCode: code,
                            );

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();

                            if (!mounted) return;
                            context.go('/');
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              verifying = false;
                              dialogErr = e.message ??
                                  'Verification failed (${e.code})';
                            });
                          } catch (e) {
                            setDialogState(() {
                              verifying = false;
                              dialogErr = 'Verification failed: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                  ),
                  child: verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, 32, 28, 24 + bottomInset),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ──────────────────────────────────────────
                  Center(
                    child: Image.asset(
                      'assets/icons/icon.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Reliable Help. Right where you are.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Title ─────────────────────────────────────────
                  const Text(
                    'Get Started with IRAMS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: kYellow,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Error banner ──────────────────────────────────
                  if (_err != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.6),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _err!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Email ─────────────────────────────────────────
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'contractor@example.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kYellow, width: 1.5),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Password ──────────────────────────────────────
                  TextFormField(
                    controller: _pass,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kYellow, width: 1.5),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  // ── Forgot password ───────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: kYellow, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Login button ──────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading || _loadingGoogle ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kYellow,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: kYellow.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black54,
                              ),
                            )
                          : const Text(
                              'Log In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── OR divider ────────────────────────────────────
                  const Row(
                    children: [
                      Expanded(child: Divider(color: kBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: kBorder)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Google sign-in ────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed:
                          _loading || _loadingGoogle ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loadingGoogle
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kYellow,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        color: Color(0xFF4285F4),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Register link ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(left: 4),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: kYellow,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
