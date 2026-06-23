import 'package:cloud_firestore/cloud_firestore.dart';

class SupportMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isFromAdmin;

  SupportMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isFromAdmin,
  });

  factory SupportMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'] as Timestamp?;
    return SupportMessage(
      id: doc.id,
      senderId: (d['senderId'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      timestamp: ts?.toDate() ?? DateTime.now(),
      isFromAdmin: d['isFromAdmin'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'isFromAdmin': isFromAdmin,
      };
}
