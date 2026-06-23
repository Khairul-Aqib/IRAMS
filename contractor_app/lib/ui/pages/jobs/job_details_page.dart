import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/firestore_service.dart';
import '../../../models/contractor.dart';
import '../../../models/job.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../chat/chat_page.dart';
import '../../widgets/payment_dialog.dart';
import '../../widgets/app_loader.dart';

class JobDetailsPage extends StatefulWidget {
  final String jobId;

  const JobDetailsPage({super.key, required this.jobId});

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  bool _isProcessing = false;
  StreamSubscription<Position>? _positionSub;
  final Stream<Contractor?> _contractorStream =
      FirestoreService.instance.watchMyContractor();

  // Separate keys per status so removing one SlideAction never corrupts another
  final _slideKeyPending = GlobalKey<SlideActionState>();
  final _slideKeyBidding = GlobalKey<SlideActionState>();
  final _slideKeyAccepted = GlobalKey<SlideActionState>();
  final _slideKeyOnTheWay = GlobalKey<SlideActionState>();
  final _slideKeyArrived = GlobalKey<SlideActionState>();
  Timer? _biddingTimer;
  bool _biddingResolved = false;
  File? _proofImage;
  bool _isUploadingProof = false;
  String? _lastWatchedJobId;

  // One-time congrats snackbar: fires once when bidding resolves in our favour
  bool _congratsSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    _retrieveLostData();
  }

  /// Recovers a photo captured just before Android killed the app to free RAM
  /// for the native camera activity. Without this, the user takes a proof
  /// photo, the OS destroys Flutter, and the photo silently vanishes.
  Future<void> _retrieveLostData() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;
      setState(() => _proofImage = File(response.file!.path));
    } catch (e) {
      debugPrint('retrieveLostData failed: $e');
    }
  }

  @override
  void dispose() {
    _stopLiveTracking();
    _biddingTimer?.cancel();
    super.dispose();
  }

  /// Starts a periodic check that resolves the bidding once the window expires.
  void _scheduleBiddingResolution(Job job) {
    if (_biddingResolved || _biddingTimer != null) return;
    if (job.biddingEndsAt == null) return;

    _biddingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) {
        _biddingTimer?.cancel();
        return;
      }
      if (DateTime.now().isAfter(job.biddingEndsAt!)) {
        _biddingTimer?.cancel();
        _biddingTimer = null;
        _biddingResolved = true;
        try {
          await FirestoreService.instance.resolveBidding(job.id);
        } catch (e) {
          debugPrint('Bidding resolution failed: $e');
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Live location tracking — streams contractor GPS to Firestore
  // ---------------------------------------------------------------------------

  /// Begins streaming the contractor's GPS position to the Job document's
  /// `ContractorGeo` field. Uses a 20-metre distance filter to limit Firestore
  /// writes and avoid quota exhaustion.
  void _startLiveTracking(String jobId) {
    // Avoid duplicate subscriptions
    if (_positionSub != null) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // metres — only fire when moved ≥ 20 m
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      FirestoreService.instance.jobs.doc(jobId).update({
        'ContractorGeo': GeoPoint(position.latitude, position.longitude),
      }).catchError((_) {
        // Non-fatal — next position event will retry
      });
    });
  }

  /// Cancels the GPS stream and clears the `ContractorGeo` field so the User
  /// app knows the contractor is no longer broadcasting.
  void _stopLiveTracking({String? jobId}) {
    _positionSub?.cancel();
    _positionSub = null;

    // Clear the field so the User app doesn't show a stale marker
    if (jobId != null) {
      FirestoreService.instance.jobs.doc(jobId).update({
        'ContractorGeo': FieldValue.delete(),
      }).catchError((_) {});
    }
  }

  /// Minimum wallet balance required to accept Cash jobs.
  static const double _minCashBalance = 20.0;

  /// Whether the given job is a Cash job that cannot be accepted due to
  /// insufficient wallet balance.
  bool _isCashJobBlocked(Job job, Contractor? contractor) {
    if (job.paymentMethod.toLowerCase() != 'cash') return false;
    final balance = contractor?.walletBalance ?? 0.0;
    return balance < _minCashBalance;
  }

  void _showCashBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.orange, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text('Insufficient Balance',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: const Text(
          'Minimum wallet balance of RM 20.00 is required to accept '
          'Cash jobs. Please top up your wallet or accept FPX jobs to '
          'earn balance.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: kYellow)),
          ),
        ],
      ),
    );
  }

  /// Enter bid / accept job — no confirmation dialog, fires directly.
  Future<void> _acceptJob(Job job, {Contractor? contractor}) async {
    if (_isProcessing) return;

    // Enforce minimum balance for Cash jobs
    if (_isCashJobBlocked(job, contractor)) {
      _showCashBlockedDialog();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await FirestoreService.instance.enterJobBid(job.id);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to place bid: ${_friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Reject Job
  /// Update Status
  Future<void> _updateStatus(Job job, JobStatus newStatus) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await FirestoreService.instance.updateJobStatus(job.id, newStatus);

      // Start / stop live GPS tracking based on status transition
      if (newStatus == JobStatus.onTheWay) {
        _startLiveTracking(job.id);
      } else if (newStatus == JobStatus.arrived ||
          newStatus == JobStatus.completed) {
        _stopLiveTracking(jobId: job.id);
      }

      if (mounted) {
        _showSuccessSnackBar('Status updated to ${newStatus.toWire()}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update: ${_friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Complete Job — calculates commission, writes ledger, shows receipt.
  static const double _commissionRate = 0.15;

  Future<void> _completeJob(Job job, {String? proofUrl}) async {
    if (_isProcessing) return;

    // Stop live tracking as soon as the contractor initiates completion
    _stopLiveTracking(jobId: job.id);

    final result = await showDialog<FinalizeJobResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FinalizeJobDialog(job: job),
    );

    if (result == null || !mounted) return;

    setState(() => _isProcessing = true);

    // ── Commission math ──
    final double price = result.totalCost;
    final double commission = price * _commissionRate;
    final double earning = price - commission;
    final bool isCash = result.paymentMethod == 'Cash';
    // Cash: contractor collected full amount, owes platform the commission.
    // FPX:  platform collected full amount, owes contractor the earning.
    final double walletDelta = isCash ? -commission : earning;

    try {
      if (isCash) {
        await FirestoreService.instance.finalizeJobCash(
          job.id,
          price,
          proofUrl: proofUrl,
          commission: commission,
          earning: earning,
          walletDelta: walletDelta,
        );
      } else {
        await FirestoreService.instance.finalizeJobOnline(
          job.id,
          price,
          proofUrl: proofUrl,
          commission: commission,
          earning: earning,
          walletDelta: walletDelta,
        );
      }

      // ── Show receipt bottom sheet ──
      if (mounted) {
        setState(() => _isProcessing = false);
        await _showEarningsReceipt(
          price: price,
          commission: commission,
          earning: earning,
          isCash: isCash,
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to finalize job: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showEarningsReceipt({
    required double price,
    required double commission,
    required double earning,
    required bool isCash,
  }) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EarningsReceiptSheet(
        price: price,
        commission: commission,
        earning: earning,
        isCash: isCash,
      ),
    );
    // After sheet dismissed, go back to home
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ---------------------------------------------------------------------------
  // Proof photo — compressed to prevent OOM / ANR
  // ---------------------------------------------------------------------------

  Future<void> _takeProofPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1080,
      );
      if (picked != null && mounted) {
        setState(() => _proofImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Could not open camera: ${_friendlyError(e)}');
      }
    }
  }

  /// Call Customer
  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) {
      _showErrorSnackBar('Phone number not available');
      return;
    }

    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to make call');
      }
    }
  }

  /// Open Chat
  void _openChat(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(jobId: job.id),
      ),
    );
  }

  /// Launch external turn-by-turn navigation to the stranded user.
  ///
  /// Mirrors the FAB behaviour in [ActiveJobMapPage]: prefers the native
  /// `google.navigation:` intent (turn-by-turn), and falls back to the
  /// Google Maps web directions URL if the intent cannot be resolved.
  Future<void> _navigateToLocation(Job job) async {
    if (job.userLatLng == null) {
      _showErrorSnackBar('Location not available');
      return;
    }

    final lat = job.userLatLng!.latitude;
    final lng = job.userLatLng!.longitude;
    final uri = Uri.parse('google.navigation:q=$lat,$lng');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web URL (driving directions)
        final webUri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to launch navigation: $e');
      if (mounted) {
        _showErrorSnackBar('Could not launch maps');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _friendlyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network')) {
      return ErrorMessages.networkError;
    } else if (errorStr.contains('permission')) {
      return 'Permission denied';
    } else if (errorStr.contains('not found')) {
      return 'Job not found';
    } else {
      return 'Something went wrong';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Job?>(
      stream: FirestoreService.instance.watchJob(widget.jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Job Details')),
            body: const AppLoader(),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Job Details')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text('Failed to load job', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final job = snapshot.data;

        // Reset proof image when job changes (e.g. navigating between jobs)
        if (job != null && _lastWatchedJobId != job.id) {
          _lastWatchedJobId = job.id;
          _proofImage = null;
          _isUploadingProof = false;

          // Auto-resume live tracking if the job is already On The Way
          if (job.status == JobStatus.onTheWay && _positionSub == null) {
            _startLiveTracking(job.id);
          }
        }

        if (job == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Job Details')),
            body: const Center(child: Text('Job not found')),
          );
        }

        // One-time congrats snackbar when we win the bid
        if (job.status == JobStatus.accepted &&
            !_congratsSnackBarShown) {
          _congratsSnackBarShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Congratulations! You secured this job.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        }

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            title: const Text('Job Details'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Status Header
                _buildStatusHeader(job),

                const SizedBox(height: 16),

                // Quick Actions
                _buildQuickActions(job),

                const SizedBox(height: 16),

                // Job Info
                _buildJobInfo(job),

                const SizedBox(height: 16),

                // Customer Info
                _buildCustomerInfo(job),

                const SizedBox(height: 16),

                // Timeline
                if (job.dateRequested != null) _buildTimeline(job),

                const SizedBox(height: 200),
              ],
            ),
          ),
          bottomSheet: _buildActionButtons(job),
        );
      },
    );
  }

  Widget _buildStatusHeader(Job job) {
    final statusInfo = _getStatusInfo(job.status);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusInfo['color'].withOpacity(0.2),
            kBg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusInfo['color'].withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: statusInfo['color'], width: 3),
            ),
            child: Icon(statusInfo['icon'], color: statusInfo['color'], size: 40),
          ),
          const SizedBox(height: 12),
          Text(
            job.status.toWire(),
            style: TextStyle(
              color: statusInfo['color'],
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.serviceType,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Job job) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.phone,
              label: 'Call',
              color: Colors.green,
              onPressed: job.userPhone.isEmpty ? null : () => _callCustomer(job.userPhone),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.chat_bubble,
              label: 'Chat',
              color: Colors.blue,
              onPressed: () => _openChat(job),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.navigation,
              label: 'Navigate',
              color: kYellow,
              onPressed: job.userLatLng == null ? null : () => _navigateToLocation(job),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfo(Job job) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.confirmation_number, label: 'Job ID', value: job.jobId),
          _InfoRow(icon: Icons.build, label: 'Service', value: job.serviceType),
          _InfoRow(icon: Icons.location_on, label: 'Location', value: job.userLocation.isEmpty ? 'Not specified' : job.userLocation),
          _InfoRow(icon: Icons.attach_money, label: 'Payment', value: 'RM ${job.totalCost.toStringAsFixed(2)}', valueColor: kYellow),
          _PaymentMethodRow(method: job.paymentMethod),
          if (job.dateRequested != null)
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Requested',
              value: DateFormat('dd MMM yyyy, hh:mm a').format(job.dateRequested!.toLocal()),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Job job) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person,
            label: 'Name',
            value: job.userName.isEmpty ? 'Not available' : job.userName,
          ),
          _InfoRow(
            icon: Icons.phone,
            label: 'Phone',
            value: job.userPhone.isEmpty ? 'Not available' : job.userPhone,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Job job) {
    final events = <Map<String, dynamic>>[];

    if (job.dateRequested != null) {
      events.add({'label': 'Requested', 'date': job.dateRequested!, 'icon': Icons.request_page, 'color': Colors.orange});
    }
    if (job.dateAccepted != null) {
      events.add({'label': 'Accepted', 'date': job.dateAccepted!, 'icon': Icons.check_circle, 'color': Colors.blue});
    }
    if (job.dateOnTheWay != null) {
      events.add({'label': 'On The Way', 'date': job.dateOnTheWay!, 'icon': Icons.directions_car, 'color': Colors.amber});
    }
    if (job.dateArrived != null) {
      events.add({'label': 'Arrived', 'date': job.dateArrived!, 'icon': Icons.place, 'color': Colors.teal});
    }
    if (job.dateInProgress != null) {
      events.add({'label': 'In Progress', 'date': job.dateInProgress!, 'icon': Icons.build, 'color': Colors.purple});
    }
    if (job.dateCompleted != null) {
      events.add({'label': 'Completed', 'date': job.dateCompleted!, 'icon': Icons.done_all, 'color': Colors.green});
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...events.map((e) => _TimelineItem(
                label: e['label'],
                date: e['date'],
                icon: e['icon'],
                color: e['color'],
                isLast: e == events.last,
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Job job) {
    if (job.status == JobStatus.completed ||
        job.status == JobStatus.cancelled ||
        job.status == JobStatus.rejected) {
      return const SizedBox.shrink();
    }

    final myUid = FirestoreService.instance.uid;
    final myContractorDocId = FirestoreService.instance.cachedContractorDocId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pending: slide to place first bid ──
            if (job.status == JobStatus.requested) ...[
              StreamBuilder<Contractor?>(
                stream: _contractorStream,
                builder: (context, cSnap) {
                  final contractor = cSnap.data;
                  final hasActiveJob = contractor?.hasActiveJob ?? false;
                  if (hasActiveJob) {
                    return _ActiveJobBlocker(onTap: () {
                      _showErrorSnackBar(
                        'Complete your current job before accepting a new one.',
                      );
                    });
                  }
                  final cashBlocked = _isCashJobBlocked(job, contractor);
                  if (cashBlocked) {
                    return _CashBlockedBanner(
                      onTap: _showCashBlockedDialog,
                    );
                  }
                  return SlideAction(
                    key: _slideKeyPending,
                    text: 'Slide to Accept Job',
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    innerColor: kYellow,
                    outerColor: const Color(0xFF333333),
                    elevation: 0,
                    sliderButtonIcon: const Icon(Icons.check, color: Colors.black),
                    height: 60,
                    borderRadius: 12,
                    enabled: !_isProcessing,
                    onSubmit: () {
                      _acceptJob(job, contractor: contractor);
                      return null;
                    },
                  );
                },
              ),
            ],

            // ── Bidding: join or wait ──
            if (job.status == JobStatus.bidding) ...[
              Builder(builder: (_) {
                // Kick off the resolution timer for this bidding window
                _scheduleBiddingResolution(job);

                final alreadyBid = job.biddingContractors.contains(myUid) ||
                    (myContractorDocId != null &&
                        job.biddingContractors.contains(myContractorDocId));

                if (alreadyBid) {
                  // Already in the pool — live countdown until bidding resolves
                  return StreamBuilder<int>(
                    stream: Stream.periodic(const Duration(seconds: 1), (_) => 0),
                    builder: (context, _) {
                      final remaining = job.biddingEndsAt != null
                          ? job.biddingEndsAt!.difference(DateTime.now()).inSeconds
                          : 0;
                      final isResolving = remaining <= 0;
                      final bidderCount = job.biddingContractors.length;

                      return Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isResolving ? kYellow.withOpacity(0.4) : kBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isResolving ? Colors.green : kYellow,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isResolving
                                  ? 'Resolving bid...'
                                  : 'Waiting for others... (${remaining}s) \u2022 $bidderCount bidder${bidderCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: isResolving ? Colors.green : Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                } else {
                  // Not yet in the pool — gate behind one-job limit + cash balance
                  return StreamBuilder<Contractor?>(
                    stream: _contractorStream,
                    builder: (context, cSnap) {
                      final contractor = cSnap.data;
                      final hasActiveJob = contractor?.hasActiveJob ?? false;
                      if (hasActiveJob) {
                        return _ActiveJobBlocker(onTap: () {
                          _showErrorSnackBar(
                            'Complete your current job before accepting a new one.',
                          );
                        });
                      }
                      final cashBlocked = _isCashJobBlocked(job, contractor);
                      if (cashBlocked) {
                        return _CashBlockedBanner(
                          onTap: _showCashBlockedDialog,
                        );
                      }
                      return SlideAction(
                        key: _slideKeyBidding,
                        text: 'Slide to Join Bid',
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        innerColor: kYellow,
                        outerColor: const Color(0xFF333333),
                        elevation: 0,
                        sliderButtonIcon: const Icon(Icons.groups, color: Colors.black),
                        height: 60,
                        borderRadius: 12,
                        enabled: !_isProcessing,
                        onSubmit: () {
                          _acceptJob(job, contractor: contractor);
                          return null;
                        },
                      );
                    },
                  );
                }
              }),
            ],

            // ── Step 1: Accepted → Go On The Way ──
            if (job.status == JobStatus.accepted)
              SlideAction(
                key: _slideKeyAccepted,
                text: 'Slide to Go On The Way',
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                innerColor: kYellow,
                outerColor: const Color(0xFF333333),
                elevation: 0,
                sliderButtonIcon: const Icon(Icons.directions_car, color: Colors.black),
                height: 60,
                borderRadius: 12,
                enabled: !_isProcessing,
                onSubmit: () {
                  _updateStatus(job, JobStatus.onTheWay); // fire-and-forget
                  return null;
                },
              ),

            // ── Step 2: On The Way → Confirm Arrival ──
            if (job.status == JobStatus.onTheWay)
              SlideAction(
                key: _slideKeyOnTheWay,
                text: 'Slide to Confirm Arrival',
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                innerColor: Colors.teal,
                outerColor: const Color(0xFF333333),
                elevation: 0,
                sliderButtonIcon: const Icon(Icons.place, color: Colors.white),
                height: 60,
                borderRadius: 12,
                enabled: !_isProcessing,
                onSubmit: () {
                  _updateStatus(job, JobStatus.arrived); // fire-and-forget
                  return null;
                },
              ),

            // ── Step 3: Arrived → Proof Photo → Complete ──
            if (job.status == JobStatus.arrived) ...[
              if (_proofImage == null)
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _isUploadingProof)
                      ? null
                      : _takeProofPhoto,
                  icon: const Icon(Icons.camera_alt, size: 22),
                  label: const Text(
                    'Take Proof Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.file(
                        _proofImage!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: (_isProcessing || _isUploadingProof)
                                ? null
                                : _takeProofPhoto,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Retake',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SlideAction(
                  key: _slideKeyArrived,
                  text: _isUploadingProof
                      ? 'Uploading...'
                      : 'Slide to Complete Job',
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  innerColor: Colors.green,
                  outerColor: const Color(0xFF333333),
                  elevation: 0,
                  sliderButtonIcon: _isUploadingProof
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle,
                          color: Colors.white),
                  height: 60,
                  borderRadius: 12,
                  enabled: !_isProcessing && !_isUploadingProof,
                  onSubmit: () {
                    // fire-and-forget: avoids dispose crash on slider animation
                    () async {
                      if (mounted) setState(() => _isUploadingProof = true);
                      try {
                        final url = await FirestoreService.instance
                            .uploadProofOfService(job.id, _proofImage!);
                        if (!mounted) return;
                        await _completeJob(job, proofUrl: url);
                      } catch (e) {
                        debugPrint('Upload Error: $e');
                        if (mounted) {
                          _showErrorSnackBar(
                            'Upload failed: ${e.toString()}',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isUploadingProof = false);
                      }
                    }();
                    return null;
                  },
                ),
              ],
              if (_proofImage == null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Take a proof photo to unlock completion',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(JobStatus status) {
    switch (status) {
      case JobStatus.requested:
        return {'color': Colors.orange, 'icon': Icons.pending_actions};
      case JobStatus.bidding:
        return {'color': Colors.amber, 'icon': Icons.groups};
      case JobStatus.accepted:
        return {'color': Colors.blue, 'icon': Icons.check_circle};
      case JobStatus.onTheWay:
        return {'color': Colors.amber, 'icon': Icons.directions_car};
      case JobStatus.arrived:
        return {'color': Colors.teal, 'icon': Icons.place};
      case JobStatus.inProgress:
        return {'color': Colors.purple, 'icon': Icons.build_circle};
      case JobStatus.completed:
        return {'color': Colors.green, 'icon': Icons.done_all};
      case JobStatus.cancelled:
        return {'color': Colors.grey, 'icon': Icons.cancel};
      case JobStatus.rejected:
        return {'color': Colors.red, 'icon': Icons.close};
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: disabled ? Colors.white24 : Colors.white),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: disabled ? Colors.white38 : Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? const Color(0xFF1A1A1A) : color.withAlpha(45),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: BorderSide(
            color: disabled ? kBorder : color.withAlpha(100),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String label;
  final DateTime date;
  final IconData icon;
  final Color color;
  final bool isLast;

  const _TimelineItem({
    required this.label,
    required this.date,
    required this.icon,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: kBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal()),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final String method;
  const _PaymentMethodRow({required this.method});

  @override
  Widget build(BuildContext context) {
    final isCash = method.toLowerCase() == 'cash';
    final label = isCash ? 'CASH' : 'FPX / ONLINE';
    final color = isCash ? Colors.green : Colors.blue;
    final icon = isCash ? Icons.payments : Icons.account_balance;
    final hint = isCash ? 'Collect cash from customer' : 'Paid online — do not collect cash';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Method', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(100)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(hint, style: TextStyle(color: color.withAlpha(160), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings Receipt Bottom Sheet
// ---------------------------------------------------------------------------

class _EarningsReceiptSheet extends StatelessWidget {
  final double price;
  final double commission;
  final double earning;
  final bool isCash;

  const _EarningsReceiptSheet({
    required this.price,
    required this.commission,
    required this.earning,
    required this.isCash,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Success icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Job Completed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Receipt card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    _ReceiptRow(
                      label: 'Total Price',
                      value: '+ RM ${price.toStringAsFixed(2)}',
                      color: Colors.white,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: kBorder, height: 1),
                    ),
                    _ReceiptRow(
                      label: 'Platform Commission (15%)',
                      value: '- RM ${commission.toStringAsFixed(2)}',
                      color: Colors.redAccent,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: kBorder, height: 1),
                    ),
                    _ReceiptRow(
                      label: 'Your Earnings',
                      value: 'RM ${earning.toStringAsFixed(2)}',
                      color: kYellow,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Wallet explanation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: (isCash ? Colors.orange : Colors.green).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isCash ? Colors.orange : Colors.green).withAlpha(60),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCash ? Icons.account_balance_wallet : Icons.add_circle_outline,
                      color: isCash ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCash
                            ? 'RM ${commission.toStringAsFixed(2)} deducted from wallet (commission on cash collected).'
                            : 'RM ${earning.toStringAsFixed(2)} added to wallet (your share of online payment).',
                        style: TextStyle(
                          color: isCash ? Colors.orange : Colors.green,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Back to Home button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _ReceiptRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: bold ? 18 : 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Disabled accept button — shown when contractor already has an active job
// ---------------------------------------------------------------------------

class _ActiveJobBlocker extends StatelessWidget {
  final VoidCallback onTap;
  const _ActiveJobBlocker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, color: Colors.white38, size: 20),
            SizedBox(width: 10),
            Text(
              'Complete current job first',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashBlockedBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CashBlockedBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(120)),
        ),
        child: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.orange, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Top up RM 20.00 to accept Cash jobs',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.info_outline, color: Colors.orange, size: 18),
          ],
        ),
      ),
    );
  }
}
