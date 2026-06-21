import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../constants/colors.dart';
import '../../../services/toyyibpay_service.dart';
import '../../../services/user_firestore_service.dart';
import '../home/user_profile.dart';
import '../map/active_job_tracking.dart';
import 'toyyibpay_webview_page.dart';

/// Payment method selection screen.
///
/// Flow: PaymentConfirmationPage → FpxPaymentPage
///   ├─ FPX   → create Job → createToyyibPayBill → ToyyibPayWebViewPage
///   └─ Cash  → create Job → ActiveJobTrackingPage
class FpxPaymentPage extends StatefulWidget {
  final String jobId;
  final String serviceType;
  final double totalAmount;
  final String userLocation;
  final String buyerEmail;
  final String buyerName;
  final String? contractorId;
  final String? batteryModel;
  final String? warranty;
  final GeoPoint? userGeo;
  final String? towingDestinationName;
  final GeoPoint? towingDestinationGeo;

  const FpxPaymentPage({
    super.key,
    required this.jobId,
    required this.serviceType,
    required this.totalAmount,
    required this.userLocation,
    required this.buyerEmail,
    required this.buyerName,
    this.contractorId,
    this.batteryModel,
    this.warranty,
    this.userGeo,
    this.towingDestinationName,
    this.towingDestinationGeo,
  });

  @override
  State<FpxPaymentPage> createState() => _FpxPaymentPageState();
}

enum _PaymentMethod { fpx, cash }

class _FpxPaymentPageState extends State<FpxPaymentPage> {
  _PaymentMethod _method = _PaymentMethod.fpx;
  bool _submitting = false;

  // Tri-state phone gate — nothing renders the payment UI until we know.
  // null   = still loading from Firestore
  // ''     = no phone on file → show profile-setup funnel
  // <text> = phone present → show payment UI
  String? _resolvedPhone;

  @override
  void initState() {
    super.initState();
    _refreshPhone();
  }

  Future<void> _refreshPhone() async {
    final contact =
        await UserFirestoreService.instance.getUserContactDetails();
    if (!mounted) return;
    setState(() => _resolvedPhone = contact['UserPhone']?.trim() ?? '');
  }

  // ── Job creation (shared by Cash and FPX) ───────────────────────────────

  /// Creates a Job doc, returning the generated JobID.
  Future<String> _createJob({
    required String paymentMethod,
    required String paymentStatus,
    String initialStatus = 'Pending',
  }) async {
    final db = FirebaseFirestore.instance;
    final counterRef = db.collection('Metadata').doc('Counters');

    final jobId = await db.runTransaction<String>((txn) async {
      final snap = await txn.get(counterRef);
      final lastNumber = (snap.data()?['lastJobNumber'] ?? 9) as int;
      final nextNumber = lastNumber + 1;
      txn.set(
          counterRef, {'lastJobNumber': nextNumber}, SetOptions(merge: true));
      return 'J${nextNumber.toString().padLeft(3, '0')}';
    });

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      throw StateError('No authenticated user — cannot create job.');
    }

    final friendlyId =
        await UserFirestoreService.instance.getCustomUserId();
    if (friendlyId.isEmpty) {
      throw StateError('No linked profile — cannot create job.');
    }

    final contactDetails =
        await UserFirestoreService.instance.getUserContactDetails();

    await db.collection('Jobs').doc(jobId).set({
      'JobID': jobId,
      'PaymentMethod': paymentMethod,
      'PaymentStatus': paymentStatus,
      'ServiceType': widget.serviceType,
      'Status': initialStatus,
      'TotalCost': widget.totalAmount,
      'UserID': '/Users/$friendlyId',
      'ownerAuthUid': authUid,
      'UserLocation': widget.userLocation,
      'UserName': contactDetails['UserName'],
      'UserPhone': contactDetails['UserPhone'],
      if (widget.userGeo != null) 'UserGeo': widget.userGeo,
      'DateRequested': FieldValue.serverTimestamp(),
      if (widget.batteryModel != null) 'BatteryModel': widget.batteryModel,
      if (widget.warranty != null) 'Warranty': widget.warranty,
      if (widget.serviceType == 'Towing' &&
          widget.towingDestinationName != null)
        'TowingDestination': widget.towingDestinationName,
      if (widget.serviceType == 'Towing' &&
          widget.towingDestinationGeo != null)
        'TowingDestinationGeo': widget.towingDestinationGeo,
    });

    return jobId;
  }

  // ── Cash flow (unchanged behaviour) ─────────────────────────────────────

  Future<void> _proceedCash() async {
    setState(() => _submitting = true);

    try {
      final jobId = await _createJob(
        paymentMethod: 'Cash',
        paymentStatus: 'Unpaid',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveJobTrackingPage(jobId: jobId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Failed to create booking: $e');
    }
  }

  // ── ToyyibPay flow ──────────────────────────────────────────────────────

  Future<void> _proceedToyyibPay() async {
    // Phone presence is enforced upstream by the build()-level gate; if we
    // reach this method, _resolvedPhone is guaranteed non-empty.
    final buyerPhone = _resolvedPhone ?? '';
    if (buyerPhone.isEmpty) return; // defensive — shouldn't happen

    setState(() => _submitting = true);

    String? createdJobId;
    try {
      createdJobId = await _createJob(
        paymentMethod: 'FPX',
        paymentStatus: 'Pending',
        initialStatus: 'Awaiting Payment',
      );

      final bill = await ToyyibPayService.instance.createBill(
        jobId: createdJobId,
        amount: widget.totalAmount,
        name: widget.buyerName,
        email: widget.buyerEmail,
        phone: buyerPhone,
      );

      if (!mounted) return;

      // push (not pushReplacement) so that if the verification page detects
      // 'Failed', popping returns the user here to retry.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ToyyibPayWebViewPage(
            jobId: createdJobId!,
            paymentUrl: bill.paymentUrl,
            returnUrl: bill.returnUrl,
          ),
        ),
      );
      if (mounted) setState(() => _submitting = false);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('ToyyibPay error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Failed to start payment: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ── Confirm button ──────────────────────────────────────────────────────

  void _onConfirmBooking() {
    if (_submitting) return;
    if (_method == _PaymentMethod.cash) {
      _proceedCash();
    } else {
      _proceedToyyibPay();
    }
  }

  bool get _canConfirm => !_submitting;

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Payment Method',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: _buildBody(),
    );
  }

  /// Tri-state body:
  ///   • _resolvedPhone == null  → loading
  ///   • _resolvedPhone is empty → profile-setup funnel (blocks payment)
  ///   • otherwise               → payment UI
  Widget _buildBody() {
    if (_resolvedPhone == null) {
      return const Center(child: CircularProgressIndicator(color: kYellow));
    }
    if (_resolvedPhone!.isEmpty) {
      return _buildSetupFunnel();
    }
    return _buildPaymentUi();
  }

  /// "Profile Setup Required" empty-state. The phone-missing message and the
  /// CTA are centralised here so the user has one obvious next step instead
  /// of a footer warning + a corner action competing for attention.
  Widget _buildSetupFunnel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Centralised graphic
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kYellow.withValues(alpha: 0.10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline,
                size: 56,
                color: kYellow,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Profile Setup Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No phone number. Update it in Profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            // Primary action — large, gold, bold. The single most important
            // task on this page until the phone is set.
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserProfile()),
                  );
                  // Re-read the phone when the user returns. If they saved
                  // a number, the body flips to the payment UI automatically.
                  if (!mounted) return;
                  setState(() => _resolvedPhone = null); // show spinner
                  await _refreshPhone();
                },
                icon: const Icon(Icons.person, size: 22),
                label: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Payment UI (unchanged from before — extracted so build() stays a
  /// readable three-way switch).
  Widget _buildPaymentUi() {
    final isCash = _method == _PaymentMethod.cash;
    return Column(
      children: [
        // ── Amount summary ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: const Color(0xFF1E1E1E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL PAYABLE',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                'RM ${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Method selector ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.account_balance,
                  label: 'Online Banking (FPX)',
                  selected: !isCash,
                  onTap: _submitting
                      ? null
                      : () => setState(() => _method = _PaymentMethod.fpx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodCard(
                  icon: Icons.payments_outlined,
                  label: 'Cash',
                  selected: isCash,
                  onTap: _submitting
                      ? null
                      : () => setState(() => _method = _PaymentMethod.cash),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(color: Color(0xFF2A2A2A), height: 1),

        Expanded(
          child: isCash ? _buildCashInfo() : _buildToyyibPayInfo(),
        ),

        // ── Confirm button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canConfirm ? const Color(0xFFFFFF00) : Colors.grey[800],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _canConfirm ? _onConfirmBooking : null,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      isCash
                          ? 'CONFIRM BOOKING'
                          : 'PAY RM ${widget.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Info panels ─────────────────────────────────────────────────────────

  Widget _buildCashInfo() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, color: Colors.yellow, size: 48),
            SizedBox(height: 16),
            Text(
              'Cash Payment',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please pay the total amount directly to the contractor '
              'once the service is completed.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToyyibPayInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance, color: Colors.yellow, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Online Banking (FPX)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You will be redirected to the ToyyibPay secure payment page '
              'to complete your FPX transfer. After payment, you will be '
              'returned to the live tracking screen.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
            ),
            if (_submitting) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: kYellow),
              const SizedBox(height: 10),
              const Text(
                'Generating secure bill…',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment method card
// ---------------------------------------------------------------------------

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2A0A) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.yellow : const Color(0xFF333333),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.yellow : Colors.white54, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.yellow : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
