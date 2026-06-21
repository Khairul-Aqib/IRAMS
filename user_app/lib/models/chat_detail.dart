import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:user_app/constants/colors.dart';
import 'package:user_app/services/user_firestore_service.dart';

/// Real-time chat that handles two modes:
///   • Job mode    — `Jobs/{jobId}/messages` per-job chat with the assigned contractor.
///   • Support mode — `SupportChats/{userId}/messages` thread with the IRAMS admin team.
///
/// Mode is inferred from whether [jobId] is null. Use the default constructor for
/// per-job chats and [ChatConversationPage.support] for support chats.
class ChatConversationPage extends StatefulWidget {
  final String chatName;

  /// Non-null for job-mode. Null for support-mode (use [.support] constructor).
  final String? jobId;

  const ChatConversationPage({
    super.key,
    required this.chatName,
    required this.jobId,
  });

  const ChatConversationPage.support({
    super.key,
    this.chatName = 'Chat with Support',
  }) : jobId = null;

  bool get isSupportMode => jobId == null;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Resolved only in support mode (U***-style ID).
  String? _supportUserId;
  bool _resolvingUserId = false;

  // Resolved only in job mode — the assigned contractor's selfie URL pulled
  // from Contractor/{C***}.SubmittedSelfieUrl. Null while loading or when no
  // selfie is on file; in either case the AppBar avatar falls back to the
  // generic person icon.
  String? _contractorSelfieUrl;

  // Tracks the most recent message timestamp we've already marked as read,
  // so we don't write a Firestore stamp on every snapshot rebuild — only
  // when something actually new arrives.
  DateTime? _lastReadStamp;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Drawer-side unread badge keys conversations as either `support` or
  /// `job_{jobId}`. Keep this in sync with `_MessagesDrawerItem`.
  String get _chatKey =>
      widget.isSupportMode ? 'support' : 'job_${widget.jobId}';

  @override
  void initState() {
    super.initState();
    if (widget.isSupportMode) {
      _resolvingUserId = true;
      _resolveSupportUserId();
    } else {
      _resolveContractorSelfie();
    }
    // Mark as read on entry — covers the case where the user opens an
    // already-read chat (we still want to refresh the timestamp so any
    // off-by-one writes don't leave a phantom badge).
    _markChatRead();
  }

  /// Writes `Users/{U***}.lastReadAt[chatKey] = serverTimestamp()`. Errors
  /// are swallowed — read tracking is best-effort and must never block the
  /// chat UI.
  Future<void> _markChatRead() async {
    try {
      final customId = await UserFirestoreService.instance.getCustomUserId();
      if (customId.isEmpty) return;
      await FirebaseFirestore.instance.collection('Users').doc(customId).set({
        'lastReadAt': {_chatKey: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal. The badge will show stale at worst.
    }
  }

  /// Re-stamps lastReadAt only when the latest message timestamp is newer
  /// than what we last marked — prevents writing to Firestore on every
  /// snapshot rebuild (the StreamBuilder fires often, but new messages
  /// arrive rarely).
  void _maybeMarkRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    DateTime? latest;
    for (final doc in docs) {
      final data = doc.data();
      final ts = data['CreatedAt'] ?? data['createdAt'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (latest == null || dt.isAfter(latest)) latest = dt;
    }
    if (latest == null) return;
    if (_lastReadStamp != null && !latest.isAfter(_lastReadStamp!)) return;
    _lastReadStamp = latest;
    _markChatRead();
  }

  Future<void> _resolveSupportUserId() async {
    final id = await UserFirestoreService.instance.getCustomUserId();
    if (!mounted) return;
    setState(() {
      _supportUserId = id.isEmpty ? null : id;
      _resolvingUserId = false;
    });
  }

  /// Follows the Job's ContractorAssigned ref (a DocumentReference set by the
  /// admin/contractor app) and reads SubmittedSelfieUrl off the Contractor
  /// doc. Errors are swallowed — the AppBar avatar just stays generic.
  Future<void> _resolveContractorSelfie() async {
    final jobId = widget.jobId;
    if (jobId == null) return;
    try {
      final jobSnap = await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(jobId)
          .get();
      final assigned = jobSnap.data()?['ContractorAssigned'];
      if (assigned is! DocumentReference) return;

      final contractorSnap = await assigned.get();
      final data = contractorSnap.data();
      if (data is! Map<String, dynamic>) return;

      final url = (data['SubmittedSelfieUrl'] as String?)?.trim();
      if (!mounted || url == null || url.isEmpty) return;
      setState(() => _contractorSelfieUrl = url);
    } catch (_) {
      // Non-fatal — AppBar will show the fallback icon.
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Refs & schema constants — branch on mode
  // ---------------------------------------------------------------------------

  /// Parent thread doc — only meaningful in support mode (used for the atomic
  /// `lastMessage`/`lastUpdated` write so admins can list threads efficiently).
  DocumentReference<Map<String, dynamic>>? get _supportThreadRef {
    if (!widget.isSupportMode || _supportUserId == null) return null;
    return FirebaseFirestore.instance
        .collection('SupportChats')
        .doc(_supportUserId);
  }

  CollectionReference<Map<String, dynamic>>? get _messagesRef {
    if (widget.isSupportMode) {
      return _supportThreadRef?.collection('messages');
    }
    return FirebaseFirestore.instance
        .collection('Jobs')
        .doc(widget.jobId!)
        .collection('messages');
  }

  // Job-mode docs were created with `CreatedAt` (PascalCase); support-mode with
  // `createdAt`. We orderBy the right key per mode but tolerate either on read.
  String get _orderKey => widget.isSupportMode ? 'createdAt' : 'CreatedAt';

  String _previewOf(String text) =>
      text.length <= 80 ? text : '${text.substring(0, 77)}...';

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    final messages = _messagesRef;
    if (text.isEmpty || messages == null) return;

    try {
      if (widget.isSupportMode) {
        final thread = _supportThreadRef!;
        final batch = FirebaseFirestore.instance.batch();
        batch.set(messages.doc(), {
          'text': text,
          'senderId': _uid,
          'isFromAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(
          thread,
          {
            'userId': _supportUserId,
            'lastMessage': _previewOf(text),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await batch.commit();
      } else {
        await messages.add({
          'senderId': _uid,
          'text': text,
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      }
      _msgCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _showContactSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Need help? Reach out to the IRAMS support team:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.email_outlined, size: 18, color: Colors.white54),
                SizedBox(width: 10),
                Text(
                  'support@irams.my',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.phone_outlined, size: 18, color: Colors.white54),
                SizedBox(width: 10),
                Text(
                  '+60 3-1234 5678',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: kYellow),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kYellow),
          onPressed: () => Navigator.pop(context),
        ),
        // Avatar + name. Avatar source depends on mode:
        //   • support mode → Logo.png asset
        //   • job mode     → contractor's SubmittedSelfieUrl, fallback to
        //                    a generic person icon while loading / on error.
        titleSpacing: 0,
        title: Row(
          children: [
            _ChatHeaderAvatar(
              isSupportMode: widget.isSupportMode,
              selfieUrl: _contractorSelfieUrl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.chatName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isSupportMode)
            IconButton(
              icon: const Icon(Icons.info_outline, color: kYellow),
              tooltip: 'Contact Info',
              onPressed: _showContactSheet,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.isSupportMode && _resolvingUserId) {
      return const Center(child: CircularProgressIndicator(color: kYellow));
    }
    if (widget.isSupportMode && _supportUserId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'No linked profile found.\nPlease try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    }

    final messagesRef = _messagesRef!;
    final extraLeading = widget.isSupportMode ? 1 : 0;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: messagesRef
                .orderBy(_orderKey, descending: false)
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
                  child: CircularProgressIndicator(color: kYellow),
                );
              }

              final docs = snap.data?.docs ?? [];

              // Each time a new message arrives while the user is viewing
              // this chat, refresh lastReadAt so the drawer badge clears in
              // real time. Only writes when the latest timestamp has
              // actually advanced — otherwise we'd thrash Firestore.
              _maybeMarkRead(docs);

              if (docs.isEmpty && !widget.isSupportMode) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No messages yet.\nSend the first message below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ),
                );
              }

              if (docs.isNotEmpty) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length + extraLeading,
                itemBuilder: (context, i) {
                  if (widget.isSupportMode && i == 0) {
                    return const _SystemWelcome();
                  }
                  final msgIndex = i - extraLeading;
                  final data = docs[msgIndex].data();

                  // Read tolerates both casings.
                  final text = (data['text'] ?? data['Text'] ?? '').toString();
                  final senderId =
                      (data['senderId'] ?? data['SenderId'] ?? '').toString();
                  final isFromAdmin = data['isFromAdmin'] == true;
                  final ts = data['createdAt'] ?? data['CreatedAt'];
                  final time = ts is Timestamp ? ts.toDate() : null;

                  final isMine = widget.isSupportMode
                      ? !isFromAdmin
                      : senderId == _uid;

                  final showTime = msgIndex == 0 ||
                      _shouldShowTime(docs, msgIndex);

                  return Column(
                    children: [
                      if (showTime && time != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            DateFormat('hh:mm a').format(time.toLocal()),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      _Bubble(
                        text: text,
                        isMine: isMine,
                        senderLabel: !isMine && widget.isSupportMode
                            ? 'Support'
                            : null,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: kCard,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  maxLines: null,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: kYellow,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowTime(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) {
    if (index == 0) return true;
    final prevData = docs[index - 1].data();
    final currData = docs[index].data();
    final prev = prevData['createdAt'] ?? prevData['CreatedAt'];
    final curr = currData['createdAt'] ?? currData['CreatedAt'];
    if (prev is! Timestamp || curr is! Timestamp) return true;
    return curr.toDate().difference(prev.toDate()).inMinutes.abs() > 5;
  }
}

// Pinned welcome card shown only in support mode.
class _SystemWelcome extends StatelessWidget {
  const _SystemWelcome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Welcome to IRAMS Support! Our Admin team is available '
          '24/7 to assist you. For life-threatening emergencies on '
          'the road, please dial 999 immediately. How can we help '
          'you today?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMine;

  /// Optional label rendered above the message (e.g. "Support" on admin
  /// bubbles). Null for the user's own messages.
  final String? senderLabel;

  const _Bubble({
    required this.text,
    required this.isMine,
    this.senderLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? kYellow.withValues(alpha: 0.2)
              : kCard,
          border: Border.all(
            color: isMine
                ? kYellow.withValues(alpha: 0.4)
                : const Color(0xFF2A2A2A),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderLabel!,
                  style: const TextStyle(
                    color: kYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar avatar — 32 px circle that shows either Logo.png (support mode) or
// the assigned contractor's SubmittedSelfieUrl (job mode), with a graceful
// person-icon fallback while loading / when no selfie is on file / on error.
// ---------------------------------------------------------------------------

class _ChatHeaderAvatar extends StatelessWidget {
  final bool isSupportMode;
  final String? selfieUrl;

  const _ChatHeaderAvatar({
    required this.isSupportMode,
    required this.selfieUrl,
  });

  static const double _diameter = 32;

  @override
  Widget build(BuildContext context) {
    final ring = BoxDecoration(
      shape: BoxShape.circle,
      color: kYellow.withValues(alpha: 0.15),
      border: Border.all(color: kYellow.withValues(alpha: 0.4), width: 1),
    );

    Widget inner;
    if (isSupportMode) {
      // Brand logo — bundled asset, no network dependency.
      inner = ClipOval(
        child: Image.asset(
          'lib/images/Logo.png',
          width: _diameter,
          height: _diameter,
          fit: BoxFit.cover,
        ),
      );
    } else if (selfieUrl != null && selfieUrl!.isNotEmpty) {
      inner = ClipOval(
        child: CachedNetworkImage(
          imageUrl: selfieUrl!,
          width: _diameter,
          height: _diameter,
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallback(),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      );
    } else {
      inner = _fallback();
    }

    return Container(
      width: _diameter,
      height: _diameter,
      decoration: ring,
      alignment: Alignment.center,
      child: inner,
    );
  }

  Widget _fallback() => const Icon(Icons.person, color: kYellow, size: 18);
}
