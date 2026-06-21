import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/chat_detail.dart';

/// Lists all jobs that have messages, showing the most recent message per job.
class ChatDetailPage extends StatelessWidget {
  const ChatDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.yellow),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Jobs')
            .where('UserID', isEqualTo: uid)
            .orderBy('DateRequested', descending: true)
            .snapshots(),
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

          final jobs = snap.data?.docs ?? [];

          if (jobs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No conversations yet.\nStart a service request to chat with a contractor.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = jobs[i];
              final data = doc.data();
              return _JobChatTile(
                jobId: doc.id,
                contractorName:
                    (data['ContractorName'] ?? data['UserName'] ?? 'Contractor')
                        .toString(),
                serviceType: (data['ServiceType'] ?? 'Service').toString(),
                status: (data['Status'] ?? '').toString(),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single job chat tile — fetches the latest message from the subcollection
// ---------------------------------------------------------------------------

class _JobChatTile extends StatelessWidget {
  final String jobId;
  final String contractorName;
  final String serviceType;
  final String status;

  const _JobChatTile({
    required this.jobId,
    required this.contractorName,
    required this.serviceType,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Jobs')
          .doc(jobId)
          .collection('messages')
          .orderBy('CreatedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, msgSnap) {
        final lastMsg = msgSnap.data?.docs.firstOrNull?.data();
        final lastText = lastMsg?['text']?.toString() ?? 'No messages yet';
        final ts = lastMsg?['CreatedAt'];
        final timeText = _formatTimestamp(ts);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatConversationPage(
                  chatName: contractorName,
                  jobId: jobId,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.yellow.withValues(alpha: 0.2),
                  child:
                      const Icon(Icons.person, color: Colors.yellow, size: 22),
                ),
                const SizedBox(width: 14),

                // Name + last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contractorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeText.isNotEmpty)
                            Text(
                              timeText,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastText,
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$serviceType  •  $status',
                        style: const TextStyle(
                            color: Colors.yellow, fontSize: 10),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic ts) {
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();
    if (ts is DateTime) dt = ts;
    if (dt == null) return '';

    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('hh:mm a').format(dt);
    }
    return DateFormat('dd MMM').format(dt);
  }
}
