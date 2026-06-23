import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import '../../../core/theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPass = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPass.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  /// Secure in-app password change flow.
  ///
  /// Steps (matches the spec exactly):
  ///  1. Validate inputs and surface errors via SnackBar.
  ///  2. Re-authenticate the user with their current password
  ///     (`EmailAuthProvider.credential` → `reauthenticateWithCredential`).
  ///  3. Call `user.updatePassword(newPassword)`.
  ///  4. On success: clear all 3 fields and show a green SnackBar.
  ///  5. On `FirebaseAuthException`: map known codes to friendly red SnackBars.
  ///
  /// The actual reauth + updatePassword Firebase calls live in
  /// `AuthService.instance.changePassword`, which already implements the
  /// exact `EmailAuthProvider.credential` → `reauthenticateWithCredential`
  /// → `updatePassword` sequence the spec describes (see
  /// `lib/services/auth_service.dart:85-105`). Keeping the logic in the
  /// service avoids duplicating Firebase plumbing across screens.
  Future<void> _save() async {
    // Dismiss the keyboard for a cleaner snackbar/loading UX.
    FocusScope.of(context).unfocus();

    final currentPassword = _currentPass.text;
    final newPassword = _newPass.text;
    final confirmPassword = _confirmPass.text;

    // ── 1. Validation ──────────────────────────────────────────────────
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showErrorSnackBar('Please fill in all password fields.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorSnackBar('New passwords do not match.');
      return;
    }

    if (newPassword.length < 8) {
      _showErrorSnackBar('New password must be at least 8 characters long.');
      return;
    }

    if (!newPassword.contains(RegExp(r'[A-Z]'))) {
      _showErrorSnackBar('New password must contain at least 1 uppercase letter (A-Z).');
      return;
    }

    if (!newPassword.contains(RegExp(r'[a-z]'))) {
      _showErrorSnackBar('New password must contain at least 1 lowercase letter (a-z).');
      return;
    }

    if (!newPassword.contains(RegExp(r'[0-9]'))) {
      _showErrorSnackBar('New password must contain at least 1 number (0-9).');
      return;
    }

    if (newPassword == currentPassword) {
      _showErrorSnackBar('New password must be different from current password.');
      return;
    }

    setState(() => _loading = true);

    try {
      // ── 2 & 3. Re-authenticate + update password (via service) ──────
      await AuthService.instance.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;

      // ── 4. Success: clear fields and show green SnackBar ───────────
      _currentPass.clear();
      _newPass.clear();
      _confirmPass.clear();

      _showSuccessSnackBar('Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      // ── 5. Firebase error mapping ──────────────────────────────────
      if (!mounted) return;
      final message = switch (e.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'Current password is incorrect.',
        'weak-password' => 'New password is too weak.',
        'requires-recent-login' =>
          'For security, please log out and log back in, then try again.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => 'Failed to change password: ${e.message ?? e.code}',
      };
      _showErrorSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('Change Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Password
              TextField(
                controller: _currentPass,
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // New Password
              TextField(
                controller: _newPass,
                obscureText: _obscureNew,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm New Password
              TextField(
                controller: _confirmPass,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Helper hint
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Minimum 8 characters, 1 uppercase, 1 lowercase, and 1 number. You will need to enter your current password to confirm.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Save Changes button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
