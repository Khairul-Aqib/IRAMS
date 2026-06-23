import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/firestore_service.dart';
import '../../../models/job.dart';
import '../../../core/theme.dart';
import '../../widgets/app_loader.dart';
import '../jobs/job_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: kCard,
      ),
      backgroundColor: kBg,
      body: StreamBuilder<List<Job>>(
        stream: FirestoreService.instance.watchMyJobs(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }

          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unable to load data at this time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          final jobs = snap.data ?? [];
          
          // Create notifications from jobs
          final notifications = <_Notification>[];
          
          // Pending jobs (highest priority)
          final pendingJobs = jobs.where((j) => j.status == JobStatus.requested).toList();
          for (final job in pendingJobs) {
            notifications.add(_Notification(
              id: job.id,
              title: 'New Job Request',
              message: '${job.serviceType} - ${job.userLocation}',
              time: job.dateRequested ?? DateTime.now(),
              icon: Icons.notification_important,
              color: Colors.orange,
              job: job,
              isUnread: true,
            ));
          }
          
          // Active jobs
          final activeJobs = jobs.where((j) =>
            j.status == JobStatus.accepted ||
            j.status == JobStatus.onTheWay ||
            j.status == JobStatus.arrived ||
            j.status == JobStatus.inProgress
          ).toList();
          
          for (final job in activeJobs) {
            String title;
            IconData icon;
            Color color;
            
            switch (job.status) {
              case JobStatus.accepted:
                title = 'Job Accepted';
                icon = Icons.check_circle;
                color = Colors.blue;
                break;
              case JobStatus.onTheWay:
                title = 'On The Way';
                icon = Icons.directions_car;
                color = Colors.amber;
                break;
              case JobStatus.arrived:
                title = 'Arrived at Location';
                icon = Icons.place;
                color = Colors.teal;
                break;
              case JobStatus.inProgress:
                title = 'Job In Progress';
                icon = Icons.build_circle;
                color = Colors.purple;
                break;
              default:
                continue;
            }
            
            notifications.add(_Notification(
              id: job.id,
              title: title,
              message: '${job.serviceType} - ${job.userLocation}',
              time: job.dateAccepted ?? job.dateRequested ?? DateTime.now(),
              icon: icon,
              color: color,
              job: job,
              isUnread: false,
            ));
          }
          
          // Recently completed jobs (last 3)
          final completedJobs = jobs
              .where((j) => j.status == JobStatus.completed)
              .toList()
            ..sort((a, b) => (b.dateCompleted ?? DateTime(2000)).compareTo(
                  a.dateCompleted ?? DateTime(2000)));
          
          for (final job in completedJobs.take(3)) {
            notifications.add(_Notification(
              id: job.id,
              title: 'Job Completed',
              message: 'RM ${job.totalCost.toStringAsFixed(2)} - ${job.serviceType}',
              time: job.dateCompleted ?? DateTime.now(),
              icon: Icons.done_all,
              color: Colors.green,
              job: job,
              isUnread: false,
            ));
          }

          if (notifications.isEmpty) {
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
                      Icons.notifications_none,
                      size: 80,
                      color: kYellow,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You\'re all caught up!',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobDetailsPage(jobId: notification.job.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Notification model
class _Notification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final IconData icon;
  final Color color;
  final Job job;
  final bool isUnread;

  _Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.job,
    required this.isUnread,
  });
}

/// Notification Card Widget
class _NotificationCard extends StatelessWidget {
  final _Notification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(notification.time);
    String timeAgo;
    
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      timeAgo = '${diff.inDays}d ago';
    } else {
      timeAgo = DateFormat('dd MMM').format(notification.time.toLocal());
    }

    return Material(
      color: notification.isUnread ? kYellow.withOpacity(0.05) : kCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isUnread 
                  ? kYellow.withOpacity(0.3) 
                  : kBorder,
              width: notification.isUnread ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: notification.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isUnread 
                                  ? FontWeight.w800 
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (notification.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kYellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Arrow
              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
