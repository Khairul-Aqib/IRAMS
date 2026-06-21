import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../services/toyyibpay_service.dart';
import '../map/active_job_tracking.dart';

/// Shown after the WebView reports the return URL has been reached.
///
/// The source of truth for success is the Jobs/{jobId} doc — only the
/// server-side toyyibPayCallback can flip PaymentStatus to 'Paid'. If that
/// webhook is delayed, the user can click 'Check Status Manually' to pull
/// the status from ToyyibPay directly (checkToyyibPayStatus function).
class PaymentVerificationPage extends StatefulWidget {
  final String jobId;

  const PaymentVerificationPage({super.key, required this.jobId});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

class _PaymentVerificationPageState extends State<PaymentVerificationPage> {
  static const _showManualCheckAfter = Duration(seconds: 20);
  static const _hardTimeout = Duration(minutes: 3);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _manualCheckTimer;
  Timer? _timeoutTimer;
  bool _resolved = false;
  bool _showManualCheck = false;
  bool _manualCheckInFlight = false;
  String? _manualCheckMessage;

  @override
  void initState() {
    super.initState();

    _sub = FirebaseFirestore.instance
        .collection('Jobs')
        .doc(widget.jobId)
        .snapshots()
        .listen(_onSnapshot);

    _manualCheckTimer = Timer(_showManualCheckAfter, () {
      if (!mounted || _resolved) return;
      setState(() => _showManualCheck = true);
    });

    _timeoutTimer = Timer(_hardTimeout, _onTimeout);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _manualCheckTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (_resolved || !snap.exists) return;
    final data = snap.data() ?? const {};
    final paymentStatus = (data['PaymentStatus'] ?? '').toString();

    if (paymentStatus == 'Paid') {
      _resolve();
      _goToTracking();
    } else if (paymentStatus == 'Failed') {
      _resolve();
      _goBackWithError('Payment failed. Please try again.');
    }
  }

  void _resolve() {
    _resolved = true;
    _manualCheckTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  void _onTimeout() {
    if (_resolved || !mounted) return;
    _resolve();
    _goBackWithError(
      'We could not confirm your payment in time. If you were charged, '
      'please check Transaction History or contact support.',
    );
  }

  Future<void> _manualCheck() async {
    if (_manualCheckInFlight || _resolved) return;
    setState(() {
      _manualCheckInFlight = true;
      _manualCheckMessage = null;
    });

    try {
      final result = await ToyyibPayService.instance
          .checkStatus(jobId: widget.jobId);
      if (!mounted || _resolved) return;

      if (result.paymentStatus == 'Paid') {
        _resolve();
        _goToTracking();
        return;
      }

      // 'Failed', 'Pending', 'NotFound', 'Error' → stay on screen, show detail.
      setState(() {
        _manualCheckInFlight = false;
        _manualCheckMessage = result.detail.isNotEmpty
            ? result.detail
            : 'Status: ${result.paymentStatus}. Please wait and try again.';
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _manualCheckInFlight = false;
        _manualCheckMessage = 'Check failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualCheckInFlight = false;
        _manualCheckMessage = 'Check failed: $e';
      });
    }
  }

  void _goToTracking() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ActiveJobTrackingPage(jobId: widget.jobId),
      ),
      (route) => route.isFirst,
    );
  }

  void _goBackWithError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.yellow),
                const SizedBox(height: 24),
                const Text(
                  'Verifying Payment…',
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Waiting for ToyyibPay to confirm your transaction. '
                  'This usually takes a few seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                if (_showManualCheck) ...[
                  const SizedBox(height: 28),
                  const Divider(color: Color(0xFF2A2A2A)),
                  const SizedBox(height: 16),
                  const Text(
                    "Taking longer than expected?",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.yellow,
                        side: const BorderSide(color: Colors.yellow),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _manualCheckInFlight ? null : _manualCheck,
                      icon: _manualCheckInFlight
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.yellow,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Check Status Manually',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_manualCheckMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _manualCheckMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
