import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../core/theme.dart';

class MfaGatePage extends StatefulWidget {
  /// Phone number passed from registration (e.g. '+60123456789').
  /// Avoids a Firestore round-trip when the number was just saved.
  final String? phoneNumber;

  const MfaGatePage({super.key, this.phoneNumber});

  @override
  State<MfaGatePage> createState() => _MfaGatePageState();
}

class _MfaGatePageState extends State<MfaGatePage> {
  bool _checkingMfa = true;
  bool _sendingOtp = false;

  String? _phoneNumber;
  String? _err;

  /// True when the contractor profile has no phone — shows an input field.
  bool _phoneMissing = false;
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Check if MFA is already enrolled
    final enrolled = await AuthService.instance.hasMfaEnrolled();
    if (!mounted) return;

    if (enrolled) {
      context.go('/');
      return;
    }

    // Use phone passed from registration if available; fall back to Firestore.
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      _phoneNumber = widget.phoneNumber;
    } else {
      try {
        final id = await FirestoreService.instance.getMyContractorDocId();
        if (id != null) {
          final doc =
              await FirestoreService.instance.contractors.doc(id).get();
          final data = doc.data();
          if (data != null) {
            _phoneNumber = (data['PhoneNumber'] ?? '').toString();
          }
        }
      } catch (_) {
        // Non-critical — user can still proceed
      }
    }

    if (mounted) {
      final hasPhone = _phoneNumber != null && _phoneNumber!.isNotEmpty;

      // Pre-fill the manual-entry field with local digits (strip +60 prefix)
      // so the user never has to re-type their number.
      if (!hasPhone && widget.phoneNumber != null) {
        var local = widget.phoneNumber!;
        if (local.startsWith('+60')) {
          local = local.substring(3);
        } else if (local.startsWith('60')) {
          local = local.substring(2);
        }
        _phoneController.text = local;
      }

      setState(() {
        _phoneMissing = !hasPhone;
        _checkingMfa = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ── Phone verification flow ──────────────────────────────────────────────

  Future<void> _enable2FA() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _err = 'Not logged in.');
      return;
    }

    // If the profile had no phone, the user must enter one manually.
    if (_phoneMissing) {
      final raw = _phoneController.text.trim();
      if (raw.isEmpty) {
        setState(() => _err = 'Please enter your phone number.');
        return;
      }
      // Normalise to +60 format
      final normalised =
          raw.startsWith('+') ? raw : '+60${raw.replaceFirst(RegExp(r'^0'), '')}';

      // Persist to Firestore before starting verification
      try {
        final id = await FirestoreService.instance.getMyContractorDocId();
        if (id != null) {
          await FirestoreService.instance.contractors.doc(id).update({
            'PhoneNumber': normalised,
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _err = 'Could not save phone number. Please try again.');
        }
        return;
      }

      _phoneNumber = normalised;
      if (mounted) setState(() => _phoneMissing = false);
    }

    final phone = _phoneNumber;
    if (phone == null || phone.isEmpty) {
      setState(() => _err = 'No phone number available.');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _err = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: (_) {
          // Timeout is handled gracefully — dialog stays open
        },
      );
    } catch (e) {
      if (mounted) setState(() => _err = 'Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  void _onVerificationCompleted(PhoneAuthCredential credential) async {
    // Auto-resolution (Android) — link and finish immediately
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.linkWithCredential(credential);
      await _markMfaEnabled();
      // Set bypass so the router guard won't bounce us back
      AuthService.instance.mfaBypassed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified automatically!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _err = 'Auto-verification failed: $e');
    }
  }

  void _onVerificationFailed(FirebaseAuthException e) {
    if (!mounted) return;
    setState(() {
      _sendingOtp = false;
      _err = e.message ?? 'Verification failed (${e.code})';
    });
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    if (!mounted) return;
    setState(() => _sendingOtp = false);
    _showOtpDialog(verificationId);
  }

  // ── OTP dialog ───────────────────────────────────────────────────────────

  Future<void> _showOtpDialog(String verificationId) async {
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
                'Enter OTP',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'A 6-digit code was sent to $_phoneNumber',
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
                            final credential =
                                PhoneAuthProvider.credential(
                              verificationId: verificationId,
                              smsCode: code,
                            );

                            final user =
                                FirebaseAuth.instance.currentUser!;
                            await user.linkWithCredential(credential);
                            await _markMfaEnabled();

                            // Set bypass before navigating so the router
                            // guard won't redirect back to /mfa
                            AuthService.instance.mfaBypassed = true;

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('2FA enabled successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
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

  /// Marks 2FA as enabled on the contractor's Firestore document.
  Future<void> _markMfaEnabled() async {
    try {
      final id = await FirestoreService.instance.getMyContractorDocId();
      if (id != null) {
        await FirestoreService.instance.contractors.doc(id).update({
          'Is2FAEnabled': true,
        });
      }
    } catch (_) {
      // Best-effort — auth-level MFA is the source of truth
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingMfa) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kYellow),
        ),
      );
    }

    final maskedPhone = _maskPhone(_phoneNumber);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Icon ──────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: kYellow.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kYellow.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: kYellow,
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ─────────────────────────────────────────────
              const Text(
                'Secure Your Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enable two-factor authentication via SMS to protect your account and receive job alerts securely.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              // ── Phone display / input ──────────────────────────────
              if (_phoneMissing)
                // No phone on profile — let the user type one in
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android,
                              color: kYellow, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '+60',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: '12 345 6789',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: kCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kBorder),
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
                )
              else if (maskedPhone != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_android,
                          color: kYellow, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        maskedPhone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_err != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _err!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // ── Enable 2FA button ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sendingOtp ? null : _enable2FA,
                  icon: _sendingOtp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black54,
                          ),
                        )
                      : const Icon(Icons.sms_outlined),
                  label: Text(
                    _sendingOtp ? 'Sending OTP...' : 'Enable 2FA (SMS)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: kYellow.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Skip for now ──────────────────────────────────────
              TextButton(
                onPressed: () {
                  AuthService.instance.mfaBypassed = true;
                  context.go('/');
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  /// Masks a phone number for display: +60*****6789
  String? _maskPhone(String? phone) {
    if (phone == null || phone.length < 6) return phone;
    final visible = phone.substring(phone.length - 4);
    final prefix = phone.substring(0, 3); // e.g. +60
    return '$prefix${'*' * (phone.length - 7)}$visible';
  }
}
