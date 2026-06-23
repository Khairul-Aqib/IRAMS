import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/support_message.dart';
import 'firestore_service.dart';

class SupportChatService {
  SupportChatService._();
  static final instance = SupportChatService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _supportChats =>
      _db.collection('SupportChats');

  /// Stream of messages for the given contractor, newest first.
  Stream<List<SupportMessage>> getMessages(String contractorId) {
    return _supportChats
        .doc(contractorId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SupportMessage.fromDoc(d)).toList());
  }

  /// Send a message from the contractor to admin support.
  Future<void> sendMessage(String contractorId, String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Add the message to the sub-collection.
    final msg = SupportMessage(
      id: '',
      senderId: uid,
      text: text,
      timestamp: DateTime.now(), // placeholder; server timestamp used in toMap
      isFromAdmin: false,
    );
    await _supportChats
        .doc(contractorId)
        .collection('messages')
        .add(msg.toMap());

    // Merge-update the parent document so the Admin portal can list active chats.
    final contractorName = await _resolveContractorName(contractorId);
    await _supportChats.doc(contractorId).set({
      'ContractorId': contractorId,
      'ContractorName': contractorName,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastMessage': text,
    }, SetOptions(merge: true));
  }

  /// Best-effort lookup of the contractor's display name.
  Future<String> _resolveContractorName(String contractorId) async {
    final cached = FirestoreService.instance.cachedContractorDocId;
    // If the contractor doc ID matches, read from that doc.
    final docId = cached ?? contractorId;
    try {
      final snap =
          await FirestoreService.instance.contractors.doc(docId).get();
      final data = snap.data();
      if (data != null) {
        final name = (data['FullName'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return 'Unknown';
  }
}
