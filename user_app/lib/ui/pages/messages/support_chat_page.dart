import 'package:flutter/material.dart';

import '../../../models/chat_detail.dart';

/// Thin wrapper kept so existing routes (drawer, requestJob entry points)
/// don't have to know about the unified [ChatConversationPage]. All
/// support-chat behavior — atomic batch, welcome banner, contact sheet,
/// "Support" admin tag — lives in `ChatConversationPage.support`.
class SupportChatPage extends StatelessWidget {
  const SupportChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatConversationPage.support();
  }
}
