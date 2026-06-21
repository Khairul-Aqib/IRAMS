import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:user_app/constants/colors.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/chat_detail.dart';
import 'package:user_app/ui/pages/messages/support_chat_page.dart';

// ---------------------------------------------------------------------------
// Message Inbox — lists jobs that have a contractor assigned
// ---------------------------------------------------------------------------

class MessageInboxPage extends StatefulWidget {
  const MessageInboxPage({super.key});

  @override
  State<MessageInboxPage> createState() => _MessageInboxPageState();
}

class _MessageInboxPageState extends State<MessageInboxPage> {
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
          'MESSAGES',
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _filterJobs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final d = doc.data();
      final assigned = d['ContractorAssigned'];
      if (assigned != null && assigned.toString().isNotEmpty) {
        results.add(doc);
        continue;
      }
      final msgs = await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(doc.id)
          .collection('messages')
          .limit(1)
          .get();
      if (msgs.docs.isNotEmpty) {
        results.add(doc);
      }
    }
    return results;
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: kYellow),
      );
    }

    final id = _friendlyId;
    if (_profileMissing || id == null || id.trim().isEmpty) {
      return const Center(
        child: Text(
          'No linked profile found.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    final userPath = '/Users/$id';

    final jobsStream = FirebaseFirestore.instance
        .collection('Jobs')
        .where('UserID', isEqualTo: userPath)
        .orderBy('DateRequested', descending: true)
        .snapshots();

    final supportStream = FirebaseFirestore.instance
        .collection('SupportChats')
        .doc(id)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: supportStream,
      builder: (context, supportSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: jobsStream,
          builder: (context, snap) {
            if (snap.hasError) {
              final err = snap.error.toString();
              if (err.contains('failed-precondition') ||
                  err.contains('requires an index')) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'A Firestore index is being built.\nPlease try again shortly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                );
              }
              return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent)),
              );
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kYellow),
              );
            }

            final allDocs = snap.data?.docs ?? [];
            final supportDoc = supportSnap.data;

            return FutureBuilder<
                List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _filterJobs(allDocs),
              builder: (context, filtSnap) {
                if (!filtSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: kYellow),
                  );
                }
                final jobs = filtSnap.data!;
                final entries = _mergeEntries(jobs, supportDoc);

                if (entries.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No conversations yet.',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    if (entry is _SupportEntry) {
                      return _SupportTile(
                        lastMessage: entry.lastMessage,
                        lastUpdated: entry.lastUpdated,
                      );
                    }
                    final job = (entry as _JobEntry).doc;
                    final d = job.data();
                    final status = (d['Status'] ?? '').toString();
                    final rawName = d['ContractorName']?.toString();
                    final jobContractorName =
                        (rawName != null && rawName.trim().isNotEmpty)
                            ? rawName.trim()
                            : null;
                    // `ContractorAssigned` is written by the admin/contractor
                    // app as a DocumentReference to Contractor/{C***}. Pulling
                    // it through gives the tile a direct, fast path to the
                    // contractor's name without guessing from message senders.
                    final assignedRaw = d['ContractorAssigned'];
                    final contractorRef =
                        assignedRaw is DocumentReference<Map<String, dynamic>>
                            ? assignedRaw
                            : null;
                    final serviceType =
                        (d['ServiceType'] ?? 'Service').toString();

                    return _InboxTile(
                      jobId: job.id,
                      jobContractorName: jobContractorName,
                      contractorRef: contractorRef,
                      serviceType: serviceType,
                      status: status,
                      currentUid:
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<_InboxEntry> _mergeEntries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
    DocumentSnapshot<Map<String, dynamic>>? supportDoc,
  ) {
    final entries = <_InboxEntry>[
      for (final j in jobs) _JobEntry(j),
    ];

    final supportData = supportDoc?.data();
    final lastMessage = supportData?['lastMessage']?.toString();
    final lastUpdatedTs = supportData?['lastUpdated'];
    if (supportData != null &&
        lastMessage != null &&
        lastMessage.isNotEmpty &&
        lastUpdatedTs is Timestamp) {
      entries.add(_SupportEntry(
        lastMessage: lastMessage,
        lastUpdated: lastUpdatedTs.toDate(),
      ));
    }

    entries.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return entries;
  }
}

// ---------------------------------------------------------------------------
// Unified entry model — job or support, sorted by latest activity
// ---------------------------------------------------------------------------

abstract class _InboxEntry {
  DateTime get sortKey;
}

class _JobEntry extends _InboxEntry {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  _JobEntry(this.doc);

  @override
  DateTime get sortKey {
    final ts = doc.data()['DateRequested'];
    return ts is Timestamp
        ? ts.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _SupportEntry extends _InboxEntry {
  final String lastMessage;
  final DateTime lastUpdated;
  _SupportEntry({required this.lastMessage, required this.lastUpdated});

  @override
  DateTime get sortKey => lastUpdated;
}

// ---------------------------------------------------------------------------
// Inbox tile — shows contractor, service, status, and latest message preview
// ---------------------------------------------------------------------------

class _InboxTile extends StatelessWidget {
  final String jobId;
  final String? jobContractorName;

  /// Direct reference to `Contractor/{C***}` for the assigned contractor —
  /// when present, this is the fastest, most reliable name source (works
  /// even before any chat messages exist).
  final DocumentReference<Map<String, dynamic>>? contractorRef;

  final String serviceType;
  final String status;
  final String currentUid;

  const _InboxTile({
    required this.jobId,
    required this.jobContractorName,
    required this.contractorRef,
    required this.serviceType,
    required this.status,
    required this.currentUid,
  });

  // Cache key is either a contractor doc path (e.g. "Contractor/C001") or
  // an auth uid — both are unique-per-contractor strings, so collision is
  // impossible. Stores both the name AND the selfie URL so scrolling the
  // inbox doesn't re-hit Firestore for the same contractor.
  static final Map<String, _ContractorInfo> _contractorInfoCache = {};

  /// Pulls the contractor's display name + selfie URL out of a Contractor doc,
  /// tolerating the canonical `FullName` and a few legacy name variants.
  /// Returns null if neither name nor selfie can be extracted.
  _ContractorInfo? _extractInfo(Map<String, dynamic>? data) {
    if (data == null) return null;
    final rawName = (data['FullName'] ??
            data['ContractorName'] ??
            data['Name'] ??
            data['name'] ??
            data['displayName'])
        ?.toString()
        .trim();
    final rawSelfie = (data['SubmittedSelfieUrl'] as String?)?.trim();

    final name = (rawName != null && rawName.isNotEmpty) ? rawName : null;
    final selfie =
        (rawSelfie != null && rawSelfie.isNotEmpty) ? rawSelfie : null;
    if (name == null && selfie == null) return null;
    return _ContractorInfo(name: name, selfieUrl: selfie);
  }

  /// Best-effort contractor resolution. Tries (in order):
  ///   1. Direct ContractorAssigned ref — fast, works before any messages.
  ///   2. Sender's auth uid → query Contractor.where(authUid == senderId).
  /// Returns null if neither path produces info.
  Future<_ContractorInfo?> _resolveContractor(String? otherSenderId) async {
    final fs = FirebaseFirestore.instance;

    // 1. Direct ref to the assigned contractor doc.
    if (contractorRef != null) {
      final cacheKey = contractorRef!.path;
      final cached = _contractorInfoCache[cacheKey];
      if (cached != null) return cached;

      final snap = await contractorRef!.get();
      final info = _extractInfo(snap.data());
      if (info != null) {
        _contractorInfoCache[cacheKey] = info;
        return info;
      }
    }

    // 2. Look the contractor up by the message sender's auth uid. Collection
    // is 'Contractor' (PascalCase) — the lowercase form was a bug.
    if (otherSenderId != null && otherSenderId.isNotEmpty) {
      final cached = _contractorInfoCache[otherSenderId];
      if (cached != null) return cached;

      final qs = await fs
          .collection('Contractor')
          .where('authUid', isEqualTo: otherSenderId)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        final info = _extractInfo(qs.docs.first.data());
        if (info != null) {
          _contractorInfoCache[otherSenderId] = info;
          return info;
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Stream recent messages so the tile updates in real time when a new
    // message arrives, even if the parent Job document hasn't changed.
    final msgsStream = FirebaseFirestore.instance
        .collection('Jobs')
        .doc(jobId)
        .collection('messages')
        .orderBy('CreatedAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: msgsStream,
      builder: (context, msgSnap) {
        final docs = msgSnap.data?.docs ?? [];
        final latest = docs.isNotEmpty ? docs.first.data() : null;
        final latestSender =
            (latest?['SenderId'] ?? latest?['senderId'] ?? '').toString();
        final latestText =
            (latest?['Text'] ?? latest?['text'] ?? '').toString();
        final ts = latest?['CreatedAt'];
        final timeText = _formatTimestamp(ts);

        final preview = latest == null
            ? 'No messages yet'
            : (latestSender == currentUid ? 'You: $latestText' : latestText);

        // Find the most recent message from someone other than the user.
        String? otherSenderId;
        for (final m in docs) {
          final s = (m.data()['SenderId'] ?? m.data()['senderId'] ?? '')
              .toString();
          if (s.isNotEmpty && s != currentUid) {
            otherSenderId = s;
            break;
          }
        }

        return FutureBuilder<_ContractorInfo?>(
          // We always run the lookup now (even when jobContractorName is set)
          // because the Job's cached name field doesn't include the selfie
          // URL — without this, the avatar stays generic forever.
          future: _resolveContractor(otherSenderId),
          builder: (context, infoSnap) {
            final info = infoSnap.data;
            final resolvedName = jobContractorName ??
                info?.name ??
                (status.toLowerCase() == 'pending'
                    ? 'Searching for Contractor...'
                    : 'Contractor');
            final selfieUrl = info?.selfieUrl;

            return _buildTile(
              context: context,
              displayName: resolvedName,
              preview: preview,
              timeText: timeText,
              selfieUrl: selfieUrl,
            );
          },
        );
      },
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required String displayName,
    required String preview,
    required String timeText,
    required String? selfieUrl,
  }) {
    return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatConversationPage(
                  chatName: displayName,
                  jobId: jobId,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                // Avatar — contractor's submitted selfie when available, else
                // the legacy generic person icon. The CircleAvatar's yellow
                // tint stays as the background ring so the visual rhythm of
                // the inbox is preserved while the selfie loads / on error.
                _ContractorAvatar(selfieUrl: selfieUrl),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$displayName — $serviceType',
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
                                  color: Colors.white38, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Last message preview
                      Text(
                        preview,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Status
                      Text(
                        status,
                        style: const TextStyle(
                            color: kYellow, fontSize: 10),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
              ],
            ),
          ),
        );
  }

  static String _formatTimestamp(dynamic ts) {
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();
    if (ts is DateTime) dt = ts;
    if (dt == null) return '';

    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('h:mm a').format(dt);
    }
    return DateFormat('dd MMM').format(dt);
  }
}

// ---------------------------------------------------------------------------
// Support tile — single persistent IRAMS Support thread
// ---------------------------------------------------------------------------

class _SupportTile extends StatelessWidget {
  final String lastMessage;
  final DateTime lastUpdated;

  const _SupportTile({
    required this.lastMessage,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeText = (lastUpdated.year == now.year &&
            lastUpdated.month == now.month &&
            lastUpdated.day == now.day)
        ? DateFormat('h:mm a').format(lastUpdated)
        : DateFormat('dd MMM').format(lastUpdated);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportChatPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            // Brand avatar for the IRAMS Support thread — uses the app logo
            // so the support row visually self-identifies without a label.
            CircleAvatar(
              radius: 22,
              backgroundColor: kYellow.withValues(alpha: 0.15),
              child: ClipOval(
                child: Image.asset(
                  'lib/images/Logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'IRAMS Support',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeText,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Support',
                    style: TextStyle(color: kYellow, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resolved contractor info — name + selfie URL pulled out of a Contractor
// doc once and cached for the lifetime of the inbox.
// ---------------------------------------------------------------------------

class _ContractorInfo {
  final String? name;
  final String? selfieUrl;
  const _ContractorInfo({this.name, this.selfieUrl});
}

/// Circle avatar that prefers the contractor's `SubmittedSelfieUrl`, falling
/// back to the legacy person icon while loading or on any error. Sized to
/// match the previous `CircleAvatar(radius: 22)` so the row layout doesn't
/// shift when a selfie comes in late.
class _ContractorAvatar extends StatelessWidget {
  final String? selfieUrl;
  const _ContractorAvatar({required this.selfieUrl});

  static const double _radius = 22;
  static const double _diameter = _radius * 2;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: _radius,
      backgroundColor: kYellow.withValues(alpha: 0.15),
      child: const Icon(Icons.person, color: kYellow, size: 22),
    );

    final url = selfieUrl;
    if (url == null || url.isEmpty) return fallback;

    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: _diameter,
          height: _diameter,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
