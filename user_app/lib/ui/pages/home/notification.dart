import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/ui/pages/map/active_job_tracking.dart';
import 'package:user_app/ui/pages/home/history.dart';

// ---------------------------------------------------------------------------
// Notification data model
// ---------------------------------------------------------------------------

class _NotifItem {
  final String docId;
  final String title;
  final String message;
  final String status;
  final String? relatedJobID;
  final DateTime? timestamp;

  _NotifItem({
    required this.docId,
    required this.title,
    required this.message,
    required this.status,
    this.relatedJobID,
    this.timestamp,
  });

  factory _NotifItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return _NotifItem(
      docId: doc.id,
      title: (d['title'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      status: (d['status'] ?? '').toString(),
      relatedJobID: d['relatedJobID'] as String?,
      timestamp: _parseTimestamp(d['timestamp']),
    );
  }

  static DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Badge config per job status
// ---------------------------------------------------------------------------

class _BadgeInfo {
  final IconData icon;
  final Color color;
  final String label;
  const _BadgeInfo(this.icon, this.color, this.label);
}

const _badgeMap = <String, _BadgeInfo>{
  'Pending': _BadgeInfo(Icons.edit_note, Color(0xFFFFFF00), 'Request Sent'),
  'Accepted': _BadgeInfo(Icons.check_circle, Color(0xFF4CAF50), 'Contractor Found'),
  'OnTheWay': _BadgeInfo(Icons.local_shipping, Color(0xFF2196F3), 'Contractor is moving'),
  'Arrived': _BadgeInfo(Icons.location_on, Color(0xFFFF9800), 'Contractor is here'),
  'Completed': _BadgeInfo(Icons.celebration, Color(0xFFFFD700), 'Service Completed'),
};

_BadgeInfo _badgeFor(String status) =>
    _badgeMap[status] ?? const _BadgeInfo(Icons.info_outline, Colors.grey, 'Update');

// ---------------------------------------------------------------------------
// Notifications page
// ---------------------------------------------------------------------------

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? _friendlyId;
  bool _loading = true;
  bool _profileMissing = false;

  @override
  void initState() {
    super.initState();
    _resolveId();
  }

  Future<void> _resolveId() async {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (authUid.isEmpty) {
      if (mounted) setState(() { _loading = false; _profileMissing = true; });
      return;
    }

    final qs = await FirebaseFirestore.instance
        .collection('Users')
        .where('authUid', isEqualTo: authUid)
        .limit(1)
        .get();

    if (qs.docs.isNotEmpty) {
      if (mounted) setState(() { _friendlyId = qs.docs.first.id; _loading = false; });
      return;
    }

    if (mounted) setState(() { _loading = false; _profileMissing = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      );
    }

    if (_profileMissing || _friendlyId == null) {
      return const Center(
        child: Text(
          'No linked profile found. Please sign in or contact support.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Listen to /Users/{friendlyId}/notifications, sorted newest-first
    final notifStream = FirebaseFirestore.instance
        .collection('Users')
        .doc(_friendlyId!)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notifStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.yellow),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, color: Colors.white24, size: 64),
                SizedBox(height: 16),
                Text(
                  'All caught up!',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final items = docs.map(_NotifItem.fromDoc).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _NotifCard(
            item: items[i],
            onTap: () => _onNotifTap(items[i]),
          ),
        );
      },
    );
  }

  Future<void> _onNotifTap(_NotifItem item) async {
    final jobId = item.relatedJobID;
    if (jobId == null || jobId.isEmpty) return;

    // Check the current job status to decide where to navigate
    final jobSnap = await FirebaseFirestore.instance
        .collection('Jobs')
        .doc(jobId)
        .get();

    if (!mounted) return;

    final jobStatus = jobSnap.data()?['Status']?.toString() ?? '';

    if (jobStatus == 'Completed') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HistoryPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveJobTrackingPage(jobId: jobId),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Notification card
// ---------------------------------------------------------------------------

class _NotifCard extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback onTap;

  const _NotifCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge = _badgeFor(item.status);
    final dateFmt = DateFormat('MMM d, yyyy – h:mm a');
    final timeText = item.timestamp != null ? dateFmt.format(item.timestamp!) : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: badge.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(badge.icon, color: badge.color, size: 22),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : badge.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (item.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      timeText,
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: write a notification document from a job status change.
// Called from the global job listener in homepage.dart.
// ---------------------------------------------------------------------------

/// Creates a notification entry under /Users/{friendlyId}/notifications.
Future<void> createJobNotification({
  required String friendlyId,
  required String jobId,
  required String newStatus,
  String? serviceType,
}) async {
  final service = serviceType ?? 'Service';

  final String title;
  final String message;

  switch (newStatus) {
    case 'Pending':
      title = 'Request Sent';
      message = 'Your $service request has been submitted.';
    case 'Accepted':
      title = 'Contractor Found';
      message = 'A contractor has accepted your $service request.';
    case 'OnTheWay':
      title = 'Contractor is moving';
      message = 'Your contractor is on the way to your location.';
    case 'Arrived':
      title = 'Contractor is here';
      message = 'Your contractor has arrived at your location.';
    case 'Completed':
      title = 'Service Completed';
      message = 'Your $service has been completed. Tap to view your receipt.';
    default:
      title = 'Job Update';
      message = 'Your job status changed to $newStatus.';
  }

  await FirebaseFirestore.instance
      .collection('Users')
      .doc(friendlyId)
      .collection('notifications')
      .add({
    'title': title,
    'message': message,
    'status': newStatus,
    'relatedJobID': jobId,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
