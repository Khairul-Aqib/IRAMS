import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/support_message.dart';
import '../../../services/firestore_service.dart';
import '../../../services/support_chat_service.dart';
import '../../../ui/widgets/app_scaffold.dart';
import '../../../ui/widgets/app_loader.dart';
import '../../../core/theme.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _text = TextEditingController();
  final _scrollController = ScrollController();

  String? _contractorId;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
    _resolveContractorId();
  }

  Future<void> _resolveContractorId() async {
    final id = await FirestoreService.instance.getMyContractorDocId();
    if (mounted) {
      setState(() {
        _contractorId = id;
        _loadingId = false;
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final t = _text.text.trim();
    if (t.isEmpty || _contractorId == null) return;

    try {
      await SupportChatService.instance.sendMessage(_contractorId!, t);
      _text.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      debugPrint('Failed to send support message: $e');
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

  void _showContactSheet(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    if (_loadingId) {
      return const AppScaffold(
        title: 'Chat with Support',
        child: AppLoader(),
      );
    }

    if (_contractorId == null) {
      return const AppScaffold(
        title: 'Chat with Support',
        child: Center(
          child: Text(
            'Unable to load your profile.\nPlease try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Chat with Support',
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Contact Info',
          onPressed: () => _showContactSheet(context),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: SupportChatService.instance.getMessages(_contractorId!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }

                if (snap.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final msgs = snap.data ?? [];

                if (msgs.isNotEmpty) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                }

                // Messages come newest-first from Firestore; reverse for
                // chronological display so the ListView sticks to the bottom.
                final ordered = msgs.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: ordered.length + 1,
                  itemBuilder: (context, i) {
                    // Index 0 = permanent system welcome message at the top
                    if (i == 0) return const _SystemWelcome();

                    final msgIndex = i - 1;
                    final m = ordered[msgIndex];
                    final showTime = msgIndex == 0 ||
                        ordered[msgIndex - 1]
                                .timestamp
                                .difference(m.timestamp)
                                .inMinutes
                                .abs() >
                            5;

                    return Column(
                      children: [
                        if (showTime)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('hh:mm a')
                                  .format(m.timestamp.toLocal()),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        _SupportBubble(
                          message: m.text,
                          isFromAdmin: m.isFromAdmin,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 10),

          // Input area
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: kBorder),
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
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _SupportBubble extends StatelessWidget {
  final String message;
  final bool isFromAdmin;

  const _SupportBubble({
    required this.message,
    required this.isFromAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // Contractor messages on the right, admin on the left.
    final isMine = !isFromAdmin;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMine ? kYellow.withValues(alpha: 0.2) : kCard,
          border: Border.all(
            color: isMine ? kYellow.withValues(alpha: 0.4) : kBorder,
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
            if (isFromAdmin)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Support',
                  style: TextStyle(
                    color: kYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
