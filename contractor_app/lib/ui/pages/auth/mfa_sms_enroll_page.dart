import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../ui/widgets/app_scaffold.dart';

/// SMS MFA Enrollment (Firebase Multi-Factor).
/// IMPORTANT:
/// - Enable Phone Auth in Firebase.
/// - Some MFA flows require recent login.
/// - The exact MFA API surface can change; treat this as a working template.
class MfaSmsEnrollPage extends StatefulWidget {
  const MfaSmsEnrollPage({super.key});

  @override
  State<MfaSmsEnrollPage> createState() => _MfaSmsEnrollPageState();
}

class _MfaSmsEnrollPageState extends State<MfaSmsEnrollPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  String? _verificationId;
  String? _err;

  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _err = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Start phone verification to enroll 2FA.
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        verificationCompleted: (cred) async {
          // Auto-retrieval succeeded (Android). Can enroll directly.
          _startResendCooldown();
          try {
            final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
            await user.multiFactor.enroll(
              assertion,
              displayName: 'SMS 2FA',
            );
            if (mounted) Navigator.of(context).pop();
          } catch (e) {
            if (mounted) setState(() => _err = e.toString());
          }
        },
        verificationFailed: (e) {
          if (mounted) setState(() => _err = e.message ?? e.code);
        },
        codeSent: (verificationId, _) {
          if (mounted) setState(() => _verificationId = verificationId);
          _startResendCooldown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (mounted) setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyAndEnroll() async {
    setState(() {
      _verifying = true;
      _err = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      if (_verificationId == null) throw Exception('Please request OTP first.');

      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _code.text.trim(),
      );

      final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
      await user.multiFactor.enroll(assertion, displayName: 'SMS 2FA');

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Enable SMS 2FA',
      child: Column(
        children: [
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_err!, style: const TextStyle(color: Colors.redAccent)),
            ),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number (E.164 format, e.g. +6012xxxxxxx)',
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: _sending
                ? 'Sending...'
                : (_resendCooldown > 0
                    ? 'Resend in ${_resendCooldown}s'
                    : (_verificationId == null ? 'Send OTP' : 'Resend OTP')),
            onPressed: (_sending || _resendCooldown > 0) ? null : _sendCode,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'OTP Code'),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: _verifying ? 'Enrolling...' : 'Verify & Enroll',
            onPressed: _verifying ? null : _verifyAndEnroll,
          ),
        ],
      ),
    );
  }
}
