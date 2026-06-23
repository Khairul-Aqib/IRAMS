import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId; // contractor uid or user uid
  final String text;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRead,
  });

  static ChatMessage fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    // Try both formats for compatibility
    final ts = (d['CreatedAt'] ?? d['createdAt']) as Timestamp?;
    return ChatMessage(
      id: doc.id,
      senderId: (d['SenderId'] ?? d['senderId'] ?? '').toString(),
      text: (d['Text'] ?? d['text'] ?? '').toString(),
      createdAt: (ts?.toDate()) ?? DateTime.now(),
      isRead: (d['IsRead'] ?? d['isRead']) == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'SenderId': senderId,
        'Text': text,
        'CreatedAt': FieldValue.serverTimestamp(),
        'IsRead': false,
      };
}