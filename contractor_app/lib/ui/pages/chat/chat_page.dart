import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/firestore_service.dart';
import '../../../models/chat_message.dart';
import '../../../ui/widgets/app_scaffold.dart';
import '../../../ui/widgets/app_loader.dart';
import '../../../core/theme.dart';

class ChatPage extends StatefulWidget {
  final String jobId;
  const ChatPage({super.key, required this.jobId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    FirestoreService.instance.markMessagesAsRead(widget.jobId);
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
    if (t.isEmpty) return;

    try {
      await FirestoreService.instance.sendMessage(widget.jobId, t);
      _text.clear();
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

  @override
  Widget build(BuildContext context) {
    final uid = FirestoreService.instance.uid;

    return AppScaffold(
      title: 'Chat with Customer',
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirestoreService.instance.watchMessages(widget.jobId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }

                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final msgs = snap.data ?? [];

                if (msgs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nSend a message to start the conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  );
                }

                // Auto-scroll when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.senderId == uid;
                    final showTime = i == 0 ||
                        msgs[i - 1].createdAt.difference(m.createdAt).inMinutes.abs() > 5;

                    return Column(
                      children: [
                        if (showTime)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('hh:mm a').format(m.createdAt.toLocal()),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        _MessageBubble(
                          message: m.text,
                          isMine: mine,
                          time: m.createdAt,
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

          // Input Area
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

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMine;
  final DateTime time;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.time,
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
          color: isMine ? kYellow.withOpacity(0.2) : kCard,
          border: Border.all(
            color: isMine ? kYellow.withOpacity(0.4) : kBorder,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}