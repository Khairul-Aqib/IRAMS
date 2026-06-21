import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firestore_service.dart';

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token == null) return;

    // IMPORTANT:
    // We store the contractor doc id (e.g. "C001") in FirestoreService after login.
    final contractorDocId = await FirestoreService.instance.getMyContractorDocId();
    if (contractorDocId == null) return;

    await FirestoreService.instance
        .contractorDocRef(contractorDocId)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
