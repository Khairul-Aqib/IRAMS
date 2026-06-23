import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../../services/fcm_service.dart';
import '../../../services/firestore_service.dart';
import '../../../models/contractor.dart';
import '../../../models/job.dart';
import '../../../core/theme.dart';
import '../jobs/inbox_page.dart';
import '../jobs/job_details_page.dart';
import '../map/active_job_map_page.dart';
import '../profile/profile_page.dart';
import '../profile/document_upload_page.dart';
import '../profile/document_status_page.dart';
import '../../widgets/contractor_drawer.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  StreamSubscription<String>? _fcmJobTapSub;
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;

  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  @override
  void dispose() {
    _fcmJobTapSub?.cancel();
    _fcmForegroundSub?.cancel();
    super.dispose();
  }

  Future<void> _setupFcm() async {
    try {
      await FcmService.instance.init();

      // Subscribe to background-tap stream (app was backgrounded, user tapped notif)
      _fcmJobTapSub = FcmService.instance.onJobTap.listen(_navigateToJob);

      // Subscribe to foreground message stream (show in-app snackbar)
      _fcmForegroundSub =
          FcmService.instance.onForegroundMessage.listen(_showForegroundAlert);

      // Handle terminated-state tap: app was killed, opened by tapping a notif.
      // consumePendingJobId() is called after init() resolves so the jobId is set.
      final pendingJobId = FcmService.instance.consumePendingJobId();
      if (pendingJobId != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _navigateToJob(pendingJobId),
        );
      }
    } catch (e) {
      // Non-fatal — shell continues to function without push notifications.
      debugPrint('FCM setup failed: $e');
    }
  }

  /// Push JobDetailsPage onto the navigator stack from this shell's context.
  void _navigateToJob(String jobId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailsPage(jobId: jobId)),
    );
  }

  /// Show an in-app snackbar when a notification arrives while the app is open.
  void _showForegroundAlert(RemoteMessage message) {
    if (!mounted) return;
    final title = message.notification?.title ?? 'New Job Request';
    final body = message.notification?.body ?? '';
    final tappableJobId = message.data['jobId'] as String?;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kYellow,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            if (body.isNotEmpty)
              Text(
                body,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
          ],
        ),
        action: tappableJobId != null
            ? SnackBarAction(
                label: 'View Job',
                textColor: Colors.black,
                onPressed: () => _navigateToJob(tappableJobId),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contractor?>(
      stream: FirestoreService.instance.watchMyContractor(),
      builder: (context, snap) {
        // While waiting for the first Firestore event, show a loader.
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBg,
            body: const Center(
              child: CircularProgressIndicator(color: kYellow),
            ),
          );
        }

        final contractor = snap.data;
        final status = contractor?.verificationStatus ?? 'pending_upload';

        // Approved → normal working app
        if (status == 'approved') {
          return _buildApprovedShell();
        }

        // Not approved → gatekeeper lock screen + profile-only nav
        return _buildGatekeeperShell(status);
      },
    );
  }

  /// The normal 3-tab shell for approved contractors.
  Widget _buildApprovedShell() {
    final pages = [
      const InboxPage(),
      const ActiveJobMapPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      appBar: _buildAppBar(),
      drawer: ContractorDrawer(
        onTabSelected: (i) => setState(() => _index = i),
      ),
      body: pages[_index],
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  /// Locked shell: shows a status-specific gate screen with only a Profile
  /// escape hatch (so the user can log out or edit their profile).
  Widget _buildGatekeeperShell(String status) {
    // When switching to gatekeeper, clamp _index so only 0 (gate) or 1 (profile)
    // are valid. This prevents stale _index == 2 from the approved shell.
    final safeIndex = _index > 1 ? 0 : _index;

    final pages = [
      _VerificationGateScreen(status: status),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      appBar: _buildAppBar(gatekeeper: true, pageIndex: safeIndex),
      drawer: ContractorDrawer(
        onTabSelected: (i) {
          if (i <= 1) setState(() => _index = i);
        },
      ),
      body: pages[safeIndex],
      bottomNavigationBar: _buildGatekeeperBottomNav(safeIndex),
    );
  }

  PreferredSizeWidget _buildAppBar({
    bool gatekeeper = false,
    int? pageIndex,
  }) {
    final idx = pageIndex ?? _index;
    final titles = gatekeeper
        ? ['Verification', 'Profile']
        : ['Jobs', 'Active Job', 'Profile'];

    if (gatekeeper) {
      return AppBar(
        backgroundColor: kCard,
        elevation: 0,
        toolbarHeight: 72,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.black,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              titles[idx],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return AppBar(
      backgroundColor: kCard,
      elevation: 0,
      toolbarHeight: 60,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            titles[idx],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating pill bottom navigation
  // ---------------------------------------------------------------------------

  Widget _buildFloatingBottomNav() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: StreamBuilder<List<Job>>(
              stream: FirestoreService.instance.watchOpenJobs(),
              builder: (context, jobSnap) {
                final openJobCount = jobSnap.data?.length ?? 0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.work_outline,
                      activeIcon: Icons.work,
                      label: 'Jobs',
                      index: 0,
                      badge: openJobCount,
                    ),
                    _buildNavItem(
                      icon: Icons.map_outlined,
                      activeIcon: Icons.map,
                      label: 'Map',
                      index: 1,
                    ),
                    _buildNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profile',
                      index: 2,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    int? badge,
  }) {
    final isActive = _index == index;

    return InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kYellow.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? kYellow : Colors.white54,
                  size: 26,
                ),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 16,
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? kYellow : Colors.white54,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gatekeeper bottom nav — only Home (gate) and Profile
  // ---------------------------------------------------------------------------

  Widget _buildGatekeeperBottomNav(int safeIndex) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.shield_outlined,
                  activeIcon: Icons.shield,
                  label: 'Verification',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Verification Gate Screen — shown when contractor is NOT approved
// =============================================================================

class _VerificationGateScreen extends StatelessWidget {
  final String status;
  const _VerificationGateScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    final _GateConfig cfg = _configFor(status);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with soft glow
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cfg.color.withOpacity(0.15),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 56),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              cfg.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              cfg.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),

            // Upload button (only for pending_upload and rejected)
            if (cfg.showUploadButton)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => status == 'rejected'
                            ? const DocumentStatusPage()
                            : const DocumentUploadPage(),
                      ),
                    );
                  },
                  icon: Icon(
                    status == 'rejected'
                        ? Icons.checklist
                        : Icons.upload_file,
                    size: 20,
                  ),
                  label: Text(
                    status == 'rejected'
                        ? 'Review & Update Documents'
                        : 'Upload Documents',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

            // Non-clickable status pill
            if (!cfg.showUploadButton) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: cfg.color.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      color: cfg.color,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Review in progress',
                      style: TextStyle(
                        color: cfg.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _GateConfig _configFor(String status) {
    switch (status) {
      case 'under_review':
        return _GateConfig(
          icon: Icons.hourglass_top,
          color: Colors.orange,
          title: 'Documents Under Review',
          subtitle:
              'Our admin team is currently reviewing your uploaded identity '
              'and compliance documents.\n'
              'You will be notified once the review is complete.',
          showUploadButton: false,
        );
      case 'rejected':
        return _GateConfig(
          icon: Icons.error,
          color: Colors.red,
          title: 'Verification Failed',
          subtitle:
              'Your documents were not approved. Please review the '
              'requirements and resubmit your updated documents.',
          showUploadButton: true,
        );
      default: // pending_upload
        return _GateConfig(
          icon: Icons.assignment_ind,
          color: kYellow,
          title: 'Complete Your Profile\nto Start Earning',
          subtitle:
              'Upload your JPJ license and PUSPAKOM inspection documents '
              'to get verified and start receiving job requests.',
          showUploadButton: true,
        );
    }
  }
}

class _GateConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool showUploadButton;

  const _GateConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.showUploadButton,
  });
}
