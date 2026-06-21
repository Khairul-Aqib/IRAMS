import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:user_app/services/user_firestore_service.dart';
import 'login.dart';
import '../home/get_started.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Registration logic
  // ---------------------------------------------------------------------------

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    // ── Client-side validation ──
    if (email.isEmpty || firstName.isEmpty || lastName.isEmpty ||
        password.isEmpty || phone.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _loading = true);

    try {
      // Step 1 — Create Firebase Auth account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final authUid = cred.user!.uid;

      // Update display name so other parts of the app can read it
      await cred.user!.updateDisplayName('$firstName $lastName');

      // Step 2 — Assign next sequential UserID (U001, U002, …) via txn.
      final customId =
          await UserFirestoreService.instance.generateNextUserId();

      // Step 3 — Create Firestore profile using the custom ID as the doc id.
      // Account-lifecycle fields:
      //   • registrationDate — exact join time (audit + Profile UI display)
      //   • status           — 'Active' on create; admin can flip later
      //   • CreatedAt        — kept for backwards compat with existing readers
      await FirebaseFirestore.instance.collection('Users').doc(customId).set({
        'authUid': authUid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'fullName': '$firstName $lastName',
        'registrationDate': FieldValue.serverTimestamp(),
        'Status': 'Active',
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      // Step 4 — Navigate to Get Started onboarding page
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GetStartedPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is disabled.';
      default:
        return 'Registration failed ($code). Please try again.';
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // SLIM TOP BAR
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // LOGO
            const SizedBox(height: 12),
            Image.asset('lib/images/Logo_2.png', height: 150),
            const SizedBox(height: 16),

            // FORM
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Register to continue using the app',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    _field(label: 'Email', icon: Icons.email, controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _field(label: 'First Name', icon: Icons.person,
                              controller: _firstNameCtrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(label: 'Last Name', icon: Icons.person_outline,
                              controller: _lastNameCtrl),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    _field(label: 'Password', icon: Icons.lock,
                        controller: _passwordCtrl, obscure: true),
                    const SizedBox(height: 14),
                    _field(label: 'Phone Number', icon: Icons.phone,
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone),

                    const SizedBox(height: 28),

                    // REGISTER BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: const TextStyle(color: Colors.white54),
                            children: [
                              TextSpan(
                                text: 'Login',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable input field that accepts a [TextEditingController].
  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
