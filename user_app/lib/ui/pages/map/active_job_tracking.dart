import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:user_app/models/job.dart';
import 'package:user_app/services/routing_service.dart';
import 'package:user_app/services/gps_utils.dart';
import 'package:user_app/services/toyyibpay_service.dart';
import 'package:user_app/constants/colors.dart';
import 'package:user_app/ui/pages/home/history.dart';
import 'package:user_app/ui/pages/home/homepage.dart';
import 'package:user_app/models/chat_detail.dart';

// Single source of truth for the contractor marker + route polyline. Material
// Blue 600 — saturated enough to read on light OSM tiles where the previous
// yellow disappeared.
const Color _kTrackColor = Color(0xFF1E88E5);

/// Full-screen tracking page that acts as a real-time state machine for the
/// active job.  Wraps all data in a Firestore [StreamBuilder] so every status
/// change, contractor assignment, or location update is reflected instantly.
class ActiveJobTrackingPage extends StatefulWidget {
  final String jobId;

  const ActiveJobTrackingPage({super.key, required this.jobId});

  @override
  State<ActiveJobTrackingPage> createState() => _ActiveJobTrackingPageState();
}

class _ActiveJobTrackingPageState extends State<ActiveJobTrackingPage> {
  final MapController _mapController = MapController();

  // Contractor live-location stream
  StreamSubscription? _contractorLocSub;
  LatLng? _contractorLatLng;
  String _contractorName = '';
  String _contractorPhone = '';

  // Route / ETA
  Timer? _etaTimer;
  List<LatLng> _route = [];
  double _etaSeconds = 0;
  double _distanceMeters = 0;

  // Prevents showing the completed dialog more than once
  bool _completedDialogShown = false;

  // Prevents showing the arrival SnackBar more than once
  bool _arrivedSnackBarShown = false;

  // Last known contractor ref to detect reassignment
  DocumentReference? _lastContractorRef;

  // Cancellation in progress
  bool _cancelling = false;

  // Manual ToyyibPay verification in progress
  bool _verifyingPayment = false;

  @override
  void initState() {
    super.initState();
    _etaTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshRoute(),
    );
  }

  @override
  void dispose() {
    _contractorLocSub?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  // ── Contractor stream ──────────────────────────────────────────────────

  void _listenToContractor(DocumentReference contractorRef) {
    if (_lastContractorRef?.path == contractorRef.path) return;
    _lastContractorRef = contractorRef;

    _contractorLocSub?.cancel();
    _contractorLocSub = contractorRef.snapshots().listen((snap) {
      final data = snap.data();
      if (data is! Map<String, dynamic>) return;

      final name = (data['FullName'] ?? '').toString();
      final phone = (data['PhoneNumber'] ?? '').toString();

      final geo = data['LastLocation'];
      LatLng? ll;
      if (geo is GeoPoint) ll = LatLng(geo.latitude, geo.longitude);

      if (mounted) {
        setState(() {
          _contractorName = name;
          _contractorPhone = phone;
          if (ll != null) _contractorLatLng = ll;
        });
      }
    });
  }

  // ── Routing / ETA ──────────────────────────────────────────────────────

  Future<void> _refreshRoute() async {
    final from = _contractorLatLng;
    final to = _cachedUserLatLng;
    if (from == null || to == null) return;

    try {
      final result = await RoutingService.instance.getRoute(from, to);
      if (!mounted) return;
      setState(() {
        _route = result.polyline;
        _etaSeconds = result.durationSeconds;
        _distanceMeters = result.distanceMeters;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _etaSeconds = estimateEtaSeconds(from, to);
        _distanceMeters = haversineDistance(from, to);
      });
    }
  }

  LatLng? _cachedUserLatLng;

  // ── Phone call ─────────────────────────────────────────────────────────

  Future<void> _callContractor() async {
    if (_contractorPhone.isEmpty) return;
    final uri = Uri.parse('tel:$_contractorPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _messageContractor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          chatName: _contractorName.isNotEmpty ? _contractorName : 'Contractor',
          jobId: widget.jobId,
        ),
      ),
    );
  }

  // ── Completed dialog ───────────────────────────────────────────────────

  /// Shown once per page-life when a job hits Completed. Branches:
  ///   • Already rated  → simple "thanks" confirmation, then History.
  ///   • Not rated yet  → star-rating prompt; on submit writes
  ///     UserRating / UserFeedback (+ camelCase mirrors) to Jobs/{jobId},
  ///     then History.
  void _showCompletedDialog(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (_completedDialogShown) return;
    _completedDialogShown = true;

    final data = snap.data() ?? const <String, dynamic>{};
    // Tolerate either casing — admin tooling may have written one or the other.
    final existingRating = data['userRating'] ?? data['UserRating'];

    if (existingRating != null) {
      _showThanksDialog();
    } else {
      _showRatingPrompt();
    }
  }

  void _showThanksDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Job Finished',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your service has been completed successfully.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goToHistory();
            },
            child: const Text('OK', style: TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingPrompt() async {
    final result = await showDialog<_RatingResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RatingDialog(),
    );

    // User dismissed via the Skip action — still flow forward to History.
    if (result == null) {
      if (mounted) _goToHistory();
      return;
    }

    try {
      final patch = <String, dynamic>{
        'UserRating': result.rating,
      };
      if (result.feedback.isNotEmpty) {
        patch['UserFeedback'] = result.feedback;
      }

      await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(widget.jobId)
          .set(patch, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for your feedback!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save rating: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) _goToHistory();
  }

  // ── Cancellation ───────────────────────────────────────────────────────

  Future<void> _confirmCancel() async {
    // Show the reason picker. Returns the chosen reason text (or the typed
    // 'Other' value); null if the user dismisses without confirming.
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true, // lets the sheet grow when the keyboard opens
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CancelReasonSheet(),
    );

    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);

    try {
      await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(widget.jobId)
          .set({
        'Status': 'Cancelled',
        'CancellationReason': reason,
        'DateCancelled': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request Cancelled'),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );

      _goToHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Manual payment verification (Awaiting Payment screen) ──────────────

  Future<void> _confirmPayment(Job job) async {
    if (_verifyingPayment) return;
    setState(() => _verifyingPayment = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Color(0xFF1E1E1E),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.yellow,
                ),
              ),
              SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Verifying with ToyyibPay...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await ToyyibPayService.instance.checkStatus(
        jobId: widget.jobId,
        billCode: job.toyyibPayBillCode,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close dialog
      setState(() => _verifyingPayment = false);

      final messenger = ScaffoldMessenger.of(context);

      if (result.paymentStatus == 'Paid') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment Verified!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveJobTrackingPage(jobId: widget.jobId),
          ),
        );
        return;
      }

      if (result.paymentStatus == 'NotFound' ||
          result.paymentStatus == 'Pending') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Payment not detected. If you just paid, please wait a few '
              'seconds and try again.',
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // 'Failed' or 'Error'
      final detail = result.detail.isNotEmpty
          ? result.detail
          : 'Could not confirm payment. Please try again or contact support.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(detail),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _verifyingPayment = false);

      final msg = e.code == 'not-found'
          ? 'We could not find this booking on the server. Please contact support.'
          : 'Could not verify payment: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _verifyingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Network error. Please check your connection and try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _goToHistory() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
      (route) => route.isFirst,
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  // ── Status helpers ─────────────────────────────────────────────────────

  String _statusText(Job job) {
    switch (job.status) {
      case JobStatus.awaitingPayment:
        return 'Awaiting Payment...';
      case JobStatus.requested:
        return 'Finding Assistance...';
      case JobStatus.accepted:
        return 'Contractor Assigned';
      case JobStatus.onTheWay:
        return 'Contractor is Coming...';
      case JobStatus.arrived:
        return 'Contractor has Arrived!';
      case JobStatus.inProgress:
        return 'Service in Progress...';
      case JobStatus.completed:
        return 'Service Finished';
      case JobStatus.cancelled:
        return 'Job Cancelled';
      case JobStatus.rejected:
        return 'Job Rejected';
      case JobStatus.unknown:
        return 'Searching for contractor...';
    }
  }

  // Status='Accepted' is the canonical trigger for "contractor assigned".
  // We trust the Status field alone — the ContractorAssigned ref may land
  // a moment later from the Admin write, but the user should already exit
  // the searching/cancellable state.
  bool _isPending(Job job) =>
      job.status == JobStatus.requested ||
      job.status == JobStatus.unknown;

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Jobs')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            ),
          );
        }

        // Error / missing
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: _buildAppBar(),
            body: Center(
              child: Text(
                snapshot.hasError
                    ? 'Error: ${snapshot.error}'
                    : 'Job not found.',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final job = Job.fromDoc(snapshot.data!);
        _cachedUserLatLng = job.userLatLng;

        // Wire contractor stream when assigned
        if (job.contractorAssignedRef != null) {
          _listenToContractor(job.contractorAssignedRef!);
        }

        // Completed → branch on whether the user has already rated.
        // Pass the snapshot so the dialog can read userRating/UserRating
        // without an extra Firestore round-trip.
        if (job.status == JobStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showCompletedDialog(snapshot.data!),
          );
        }

        // Arrived → one-time SnackBar to grab attention
        if (job.status == JobStatus.arrived && !_arrivedSnackBarShown) {
          _arrivedSnackBarShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.yellow, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your contractor has arrived!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFF2A2A2A),
                duration: Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        }

        final pending = _isPending(job);
        final hasContractor =
            job.contractorAssignedRef != null && _contractorName.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Stack(
            children: [
              // ── Map ──
              _buildMap(job),

              // ── Status header ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _StatusHeader(
                  statusText: _statusText(job),
                  isPending: pending,
                  isArrived: job.status == JobStatus.arrived,
                  onBack: _goToHistory,
                ),
              ),

              // ── ETA banner ──
              if (_etaSeconds > 0 &&
                  _contractorLatLng != null &&
                  {JobStatus.accepted, JobStatus.onTheWay, JobStatus.inProgress}
                      .contains(job.status))
                Positioned(
                  top: MediaQuery.of(context).padding.top + 72,
                  left: 16,
                  right: 16,
                  child: _EtaBanner(
                    etaSeconds: _etaSeconds,
                    distanceMeters: _distanceMeters,
                  ),
                ),

              // ── Bottom panel (job details + contractor / cancel) ──
              _JobDetailsSheet(
                job: job,
                isPending: pending,
                hasContractor: hasContractor,
                contractorName: _contractorName,
                contractorPhone: _contractorPhone,
                cancelling: _cancelling,
                onCancel: _confirmCancel,
                onCall: _contractorPhone.isNotEmpty ? _callContractor : null,
                onMessage: _messageContractor,
                verifyingPayment: _verifyingPayment,
                onConfirmPayment: job.status == JobStatus.awaitingPayment
                    ? () => _confirmPayment(job)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF121212),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _goToHistory,
      ),
      title: const Text(
        'Job Tracking',
        style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMap(Job job) {
    final fallback = const LatLng(3.139, 101.6869);
    final center = job.userLatLng ?? _contractorLatLng ?? fallback;

    // Once both user + contractor positions are known, fit both into view.
    if (job.userLatLng != null && _contractorLatLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(
                  [job.userLatLng!, _contractorLatLng!]),
              padding: const EdgeInsets.all(80),
            ),
          );
        } catch (_) {}
      });
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.user_app',
        ),

        // Route polyline — saturated blue reads cleanly on the OSM tiles,
        // whereas yellow gets lost on highways and light terrain.
        if (_route.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _route,
                strokeWidth: 5,
                color: _kTrackColor,
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            // User / breakdown location (static red pin)
            if (job.userLatLng != null)
              Marker(
                point: job.userLatLng!,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
            // Contractor live marker — wrapped in a white halo so the blue
            // truck pops on dark or busy map regions.
            if (_contractorLatLng != null)
              Marker(
                point: _contractorLatLng!,
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _kTrackColor.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_shipping,
                    color: _kTrackColor,
                    size: 26,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Status Header (with animated spinner while pending)
// =============================================================================

class _StatusHeader extends StatefulWidget {
  final String statusText;
  final bool isPending;
  final bool isArrived;
  final VoidCallback onBack;

  const _StatusHeader({
    required this.statusText,
    required this.isPending,
    required this.isArrived,
    required this.onBack,
  });

  @override
  State<_StatusHeader> createState() => _StatusHeaderState();
}

class _StatusHeaderState extends State<_StatusHeader>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPending) _spinCtrl.repeat();
    if (widget.isArrived) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusHeader old) {
    super.didUpdateWidget(old);
    if (widget.isPending && !_spinCtrl.isAnimating) {
      _spinCtrl.repeat();
    } else if (!widget.isPending && _spinCtrl.isAnimating) {
      _spinCtrl.stop();
    }
    if (widget.isArrived && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isArrived && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    const baseStyle = TextStyle(
      color: Colors.yellow,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    final titleWidget = widget.isArrived
        ? ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.08).animate(
              CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
            ),
            alignment: Alignment.centerLeft,
            child: Text(widget.statusText, style: baseStyle),
          )
        : Text(widget.statusText, style: baseStyle);

    return Container(
      padding: EdgeInsets.fromLTRB(4, topPad, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        boxShadow: [
          BoxShadow(
              color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack,
          ),
          Expanded(child: titleWidget),
          if (widget.isPending)
            RotationTransition(
              turns: _spinCtrl,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: Icon(Icons.sync, color: Colors.yellow, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// ETA Banner
// =============================================================================

class _EtaBanner extends StatelessWidget {
  final double etaSeconds;
  final double distanceMeters;

  const _EtaBanner({
    required this.etaSeconds,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final eta = formatEta(etaSeconds);
    final dist = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${distanceMeters.round()} m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: kYellow, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Arriving in',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  eta,
                  style: const TextStyle(
                    color: kYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Text(dist,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

// =============================================================================
// Job Details Bottom Sheet (DraggableScrollableSheet)
// =============================================================================

class _JobDetailsSheet extends StatefulWidget {
  final Job job;
  final bool isPending;
  final bool hasContractor;
  final String contractorName;
  final String contractorPhone;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final bool verifyingPayment;
  final VoidCallback? onConfirmPayment;

  const _JobDetailsSheet({
    required this.job,
    required this.isPending,
    required this.hasContractor,
    required this.contractorName,
    required this.contractorPhone,
    required this.cancelling,
    required this.onCancel,
    this.onCall,
    this.onMessage,
    this.verifyingPayment = false,
    this.onConfirmPayment,
  });

  @override
  State<_JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends State<_JobDetailsSheet> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final serviceParts = job.serviceType.split(' – ');
    final displayService = serviceParts.first.trim();
    final specifics =
        serviceParts.length > 1 ? serviceParts.sublist(1).join(' – ').trim() : null;

    final isBatteryOrTyre = job.serviceType.toLowerCase().contains('battery') ||
        job.serviceType.toLowerCase().contains('tyre');

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle — tap to toggle ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // ── Title row (always visible) ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayService,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),

            // ── Collapsible details ──
            AnimatedCrossFade(
              firstChild: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow('JOB ID', job.jobId),

                    if (job.userLocation.isNotEmpty)
                      _detailRow('LOCATION', job.userLocation),

                    _detailRow(
                      'ESTIMATED COST',
                      'RM ${job.totalCost.toStringAsFixed(2)}',
                    ),

                    if (isBatteryOrTyre &&
                        specifics != null &&
                        specifics.isNotEmpty)
                      _detailRow('MODEL', specifics),

                    const SizedBox(height: 4),
                    const Divider(color: Color(0xFF2A2A2A)),
                    const SizedBox(height: 8),

                    // ── Pending: searching + estimated arrival ──
                    if (widget.isPending && !widget.hasContractor) ...[
                      const Text(
                        'Searching for nearby service provider...',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Estimated Arrival',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '5 - 10 mins',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Contractor info ──
                    if (widget.hasContractor) ...[
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.white54, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.contractorName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (widget.contractorPhone.isNotEmpty)
                                  Text(
                                    widget.contractorPhone,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.onMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.yellow,
                                    side:
                                        const BorderSide(color: Colors.yellow),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: widget.onMessage,
                                  icon: const Icon(Icons.chat_bubble_outline,
                                      size: 16),
                                  label: const Text('Message',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          if (widget.onCall != null)
                            SizedBox(
                              height: 36,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.yellow,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: widget.onCall,
                                icon: const Icon(Icons.phone, size: 16),
                                label: const Text('Call',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Cancel / Helpdesk ──
                    if (widget.isPending)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              widget.cancelling ? null : widget.onCancel,
                          child: widget.cancelling
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : const Text(
                                  'Cancel Request',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      )
                    else if (!widget.isPending &&
                        job.status != JobStatus.completed &&
                        job.status != JobStatus.cancelled) ...[
                      if (job.status == JobStatus.awaitingPayment &&
                          widget.onConfirmPayment != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  Colors.yellow.withValues(alpha: 0.5),
                              disabledForegroundColor: Colors.black54,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: widget.verifyingPayment
                                ? null
                                : widget.onConfirmPayment,
                            child: widget.verifyingPayment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'Confirm Payment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Awaiting Payment shows Cancel (with reason picker) so
                      // the user can back out before they pay; every other
                      // post-pending state keeps the Helpdesk fallback because
                      // a contractor is already en-route or on-site and the
                      // user shouldn't self-cancel from there.
                      if (job.status == JobStatus.awaitingPayment)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                widget.cancelling ? null : widget.onCancel,
                            child: widget.cancelling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                : const Text(
                                    'Cancel Request',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.yellow,
                              side: const BorderSide(color: Colors.yellow),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final uri = Uri.parse('tel:1800-MY-HELP');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            icon: const Icon(Icons.headset_mic, size: 18),
                            label: const Text(
                              'Call Helpdesk',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              secondChild: SizedBox(height: bottomPad + 8),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Cancellation reason picker — bottom sheet that returns the chosen reason
// (a String) to the caller via Navigator.pop. Returns null if dismissed.
// Pattern: radio list of canned reasons; selecting 'Other' reveals a free
// text field whose contents become the returned reason instead.
// =============================================================================

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  static const List<String> _options = [
    'Wait time too long',
    'Found another provider',
    'Price too high',
    'Changed my mind',
    'Other',
  ];

  String? _selected;
  final TextEditingController _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  bool get _isOther => _selected == 'Other';

  /// Submit allowed when a canned reason is picked, OR 'Other' is picked AND
  /// the free-text field has non-whitespace content.
  bool get _canSubmit {
    if (_selected == null) return false;
    if (_isOther) return _otherCtrl.text.trim().isNotEmpty;
    return true;
  }

  void _submit() {
    final reason = _isOther ? _otherCtrl.text.trim() : _selected!;
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    // Lift the sheet above the keyboard when 'Other' is being typed.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Why are you cancelling?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your feedback helps us improve.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Flutter 3.32+ moved the group value / onChanged off each
          // RadioListTile and onto a RadioGroup ancestor — the tiles read
          // the current value from this ancestor automatically.
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in _options)
                  RadioListTile<String>(
                    value: option,
                    activeColor: kYellow,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),

          // Conditional 'Other' free-text field — only rendered when needed
          // so it can't accidentally collect text the user didn't intend to
          // submit (e.g. they typed something then switched to a canned option).
          if (_isOther) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _otherCtrl,
              autofocus: true,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: kYellow,
              // Trigger a rebuild so _canSubmit re-evaluates as the user types.
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tell us why...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keep Request'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.redAccent.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text(
                    'Confirm Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Star-rating prompt — shown automatically when a job hits Completed and the
// user hasn't rated it yet. Returns a [_RatingResult] to the caller via
// Navigator.pop, or null if the user dismisses via "Skip".
// =============================================================================

class _RatingResult {
  final int rating;
  final String feedback;
  const _RatingResult({required this.rating, required this.feedback});
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  final TextEditingController _feedbackCtrl = TextEditingController();

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating < 1) return;
    Navigator.of(context).pop(
      _RatingResult(
        rating: _rating,
        feedback: _feedbackCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: const Text(
        'Rate Your Service',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How was your experience? Your feedback helps us improve.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Center(
              child: _StarBar(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
            const SizedBox(height: 8),
            // Tiny label that updates as the user picks — gives them feedback
            // that the tap landed without needing a screen reader.
            Center(
              child: Text(
                _rating == 0 ? 'Tap a star to rate' : _ratingLabel(_rating),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _feedbackCtrl,
              maxLength: 300,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.yellow,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      actions: [
        // Skip — pops null so the caller can still navigate to History.
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Skip',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: _rating >= 1 ? _submit : null,
          child: Text(
            'Submit',
            style: TextStyle(
              color: _rating >= 1 ? Colors.yellow : Colors.yellow.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static String _ratingLabel(int n) {
    switch (n) {
      case 1:
        return 'Very poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

/// Five tappable stars. `value` is the current rating (0 = unrated); tapping
/// star N sets value to N. No external package — just five icons in a row,
/// which is the entire spec of `flutter_rating_bar` for this use-case.
class _StarBar extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = starIndex <= value;
        return IconButton(
          onPressed: () => onChanged(starIndex),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          iconSize: 36,
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? Colors.amber : Colors.white24,
          ),
        );
      }),
    );
  }
}
