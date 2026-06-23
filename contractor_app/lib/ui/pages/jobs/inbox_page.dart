import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/firestore_service.dart';
import '../../../models/job.dart';
import '../../../models/contractor.dart';
import '../../../core/theme.dart';
import '../../widgets/app_loader.dart';
import 'job_details_page.dart';
import '../profile/document_upload_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  int _refreshKey = 0;

  Future<void> _onRefresh() async {
    setState(() => _refreshKey++);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _toggleAvailability(bool value) async {
    try {
      await FirestoreService.instance.setAvailability(value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildAvailabilityBanner(Contractor contractor) {
    final isOnline = contractor.isAvailable;
    return GestureDetector(
      onTap: () => _toggleAvailability(!isOnline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isOnline
              ? Colors.green.withOpacity(0.15)
              : const Color(0xFF1A1A1A),
          border: Border(
            bottom: BorderSide(
              color: isOnline
                  ? Colors.green.withOpacity(0.4)
                  : kBorder,
            ),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? Colors.green : Colors.white38,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isOnline
                        ? 'You can receive job requests'
                        : 'Tap to go online and receive jobs',
                    style: TextStyle(
                      color: isOnline
                          ? Colors.green.withOpacity(0.7)
                          : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isOnline,
              activeColor: Colors.green,
              onChanged: (v) => _toggleAvailability(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 72,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'You are currently offline',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Go online to start receiving\njob requests from customers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationGate(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 72,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Pending Approval',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your account must be verified by an admin before you can view or accept job requests.\n\nPlease upload your verification documents and wait for approval.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DocumentUploadPage(),
                ),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspendedGate() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 72, color: Colors.redAccent),
            SizedBox(height: 24),
            Text(
              'Account Suspended',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              'Your account has been suspended by an administrator. You cannot view or accept jobs at this time.\n\nPlease contact support for assistance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contractor?>(
      stream: FirestoreService.instance.watchMyContractor(),
      builder: (context, contractorSnap) {
        final contractor = contractorSnap.data;

        // Loading guard: stream hasn't emitted yet, show spinner
        if (contractorSnap.connectionState == ConnectionState.waiting &&
            contractor == null) {
          return const AppLoader();
        }

        // Gate: suspended contractors are blocked first (distinct message)
        if (contractorSnap.connectionState != ConnectionState.waiting &&
            contractor != null &&
            contractor.accountStatus.toLowerCase() == 'suspended') {
          return _buildSuspendedGate();
        }

        // Gate: only verified contractors see the inbox
        if (contractorSnap.connectionState != ConnectionState.waiting &&
            (contractor == null ||
                contractor.verificationStatus != 'approved')) {
          return _buildVerificationGate(context);
        }

        // contractor is guaranteed non-null here — the gate above returned early if null.
        final c = contractor!;
        return Column(
          children: [
            // Availability banner (always visible for verified contractors)
            _buildAvailabilityBanner(c),

            // Offline gate — hides job list entirely when not available
            if (!c.isAvailable)
              Expanded(child: _buildOfflineState())
            else
              // Jobs List — directly below the availability banner
              Expanded(
                child: StreamBuilder<List<Job>>(
                  key: ValueKey(_refreshKey),
                  stream: FirestoreService.instance.watchOpenJobs(),
                  builder: (context, snap) {
                    debugPrint('INBOX: state=${snap.connectionState} hasData=${snap.hasData} hasError=${snap.hasError}');

                    if (snap.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    if (snap.hasError) {
                      return _buildErrorState(snap.error.toString());
                    }

                    final inboxJobs = snap.data ?? [];

                    if (inboxJobs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: kYellow,
                      backgroundColor: kCard,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        itemCount: inboxJobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final job = inboxJobs[i];
                          return _ModernJobCard(
                            job: job,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailsPage(jobId: job.id),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ); // inner Column
      },
    ); // outer StreamBuilder<Contractor?>
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kYellow),
          SizedBox(height: 16),
          Text(
            'Loading jobs...',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to load jobs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kYellow.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox,
              size: 80,
              color: kYellow,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No jobs yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'New jobs will appear here when customers request your services',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kYellow,
              side: const BorderSide(color: kYellow),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}



class _ModernJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const _ModernJobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(job.status);
    final Color statusColor = statusInfo['color'] as Color;
    final isCash = job.paymentMethod.toLowerCase() == 'cash';

    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 1. Top Row: Service & Status ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getServiceIcon(job.serviceType),
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      job.serviceType,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge — live countdown for Bidding jobs
                  if (job.status == JobStatus.bidding &&
                      job.biddingEndsAt != null)
                    StreamBuilder<int>(
                      stream: Stream.periodic(
                          const Duration(seconds: 1), (_) => 0),
                      builder: (context, _) {
                        final remaining = job.biddingEndsAt!
                            .difference(DateTime.now())
                            .inSeconds;
                        final isResolving = remaining <= 0;
                        final c = isResolving
                            ? Colors.amber
                            : Colors.deepOrange;
                        return _statusChip(
                          color: c,
                          icon: isResolving
                              ? null
                              : Icons.local_fire_department,
                          label: isResolving
                              ? 'Resolving...'
                              : '${remaining}s left',
                        );
                      },
                    )
                  else
                    _statusChip(
                      color: statusColor,
                      label: job.status.toWire(),
                    ),
                ],
              ),

              // ── 2. Middle: Location & Time ──
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on,
                        size: 15, color: Colors.white38),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.userLocation.isEmpty
                          ? 'Location not available'
                          : job.userLocation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (job.dateRequested != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 23),
                  child: Text(
                    DateFormat('dd MMM, hh:mm a')
                        .format(job.dateRequested!.toLocal()),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              // ── 3. Bottom Row: Payment & Price ──
              const SizedBox(height: 12),
              const Divider(color: kBorder, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Payment method icon + label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCash
                            ? Icons.payments
                            : Icons.account_balance_wallet,
                        color: isCash ? Colors.green : Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCash ? 'Cash' : 'FPX',
                        style: TextStyle(
                          color: isCash ? Colors.green : Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  // Price — large & prominent
                  Text(
                    'RM ${job.totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: kYellow,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required Color color,
    required String label,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'towing':
        return Icons.local_shipping;
      case 'battery jump-start':
      case 'battery replacement':
        return Icons.battery_charging_full;
      case 'tyre change':
        return Icons.tire_repair;
      case 'fuel delivery':
        return Icons.local_gas_station;
      case 'vehicle unlock':
        return Icons.lock_open;
      default:
        return Icons.build;
    }
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

