import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/job.dart';
import '../models/chat_message.dart';
import '../models/contractor.dart';
import '../models/review.dart';
import '../models/wallet_transaction.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get user => FirebaseAuth.instance.currentUser;
  String get uid => user?.uid ?? '';

  String? _cachedContractorDocId;

  /// The Firestore document ID of the current contractor (may differ from Auth UID).
  /// Populated after the first successful [getMyContractorDocId] call.
  String? get cachedContractorDocId => _cachedContractorDocId;

  CollectionReference<Map<String, dynamic>> get contractors =>
      _db.collection('Contractor');

  CollectionReference<Map<String, dynamic>> get jobs =>
      _db.collection('Jobs');

  CollectionReference<Map<String, dynamic>> get invoices =>
      _db.collection('JobInvoice');

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('Users');

  CollectionReference<Map<String, dynamic>> get services =>
      _db.collection('Services');

  CollectionReference<Map<String, dynamic>> get withdrawals =>
      _db.collection('Withdrawals');

  DocumentReference<Map<String, dynamic>> contractorDocRef(String contractorId) {
    return contractors.doc(contractorId);
  }

  Future<String?> getMyContractorDocId() async {
    if (_cachedContractorDocId != null) {
      debugPrint('✅ Using cached contractor ID: $_cachedContractorDocId');
      return _cachedContractorDocId;
    }

    final u = user;
    if (u == null) {
      debugPrint('❌ No Firebase Auth user found');
      return null;
    }

    final uid = u.uid;
    final email = u.email?.trim().toLowerCase();
    
    debugPrint('🔍 Looking up contractor:');
    debugPrint('   - Auth UID: $uid');
    debugPrint('   - Auth Email: $email');

    if (email == null || email.isEmpty) {
      debugPrint('❌ User has no email');
      return null;
    }

    try {
      debugPrint('🔎 Searching by Email field...');
      final emailQuery = await contractors
          .where('Email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        _cachedContractorDocId = emailQuery.docs.first.id;
        debugPrint('✅ Found contractor by Email: $_cachedContractorDocId');
        return _cachedContractorDocId;
      }

      debugPrint('🔎 Trying Auth UID as document ID...');
      final uidDoc = await contractors.doc(uid).get();
      
      if (uidDoc.exists) {
        _cachedContractorDocId = uid;
        debugPrint('✅ Found contractor by UID: $_cachedContractorDocId');
        return _cachedContractorDocId;
      }

      debugPrint('❌ No contractor found!');
      debugPrint('📋 Available contractors in Firestore:');
      
      final allContractors = await contractors.limit(10).get();
      if (allContractors.docs.isEmpty) {
        debugPrint('  ⚠️ Contractor collection is EMPTY!');
      } else {
        for (final doc in allContractors.docs) {
          final data = doc.data();
          debugPrint('  - ID: ${doc.id}');
          debugPrint('    Email: ${data['Email']}');
          debugPrint('    Name: ${data['FullName']}');
          debugPrint('    Status: ${data['Status']}');
        }
      }
      
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getMyContractorDocId: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _myContractorDocRef() async {
    final id = await getMyContractorDocId();
    if (id == null) return null;
    return contractorDocRef(id);
  }

  Stream<Contractor?> watchMyContractor() async* {
    final ref = await _myContractorDocRef();
    if (ref == null) {
      yield null;
      return;
    }

    yield* ref.snapshots().map((snap) {
      if (!snap.exists) return null;
      return Contractor.fromDoc(snap);
    });
  }

  /// Queries the Contractor collection for the highest existing ConID,
  /// increments the numeric part, and returns the next ID (e.g. 'C008').
  /// Falls back to 'C001' if no contractors exist or ConID is absent.
  Future<String> generateNextConId() async {
    final snap = await contractors
        .orderBy('ConID', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 'C001';

    final lastConId = snap.docs.first.data()['ConID'];
    if (lastConId == null || lastConId is! String || lastConId.length < 2) {
      return 'C001';
    }

    final numericPart = int.tryParse(lastConId.substring(1));
    if (numericPart == null) return 'C001';

    final next = numericPart + 1;
    return 'C${next.toString().padLeft(3, '0')}';
  }

  Future<void> upsertContractorProfileAdminFormat({
    required String contractorId,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String companyName,
    required String companyContactPhone,
    required String location,
    required List<String> serviceTypes,
  }) async {
    final conId = await generateNextConId();

    await contractors.doc(contractorId).set({
      'AccountStatus': 'Active',
      'CompanyContactPhone': companyContactPhone,
      'CompanyName': companyName,
      'ConID': conId,
      'ContractorID': contractorId,
      'Distance': '0km',
      'Email': email.trim().toLowerCase(),
      'FullName': fullName,
      'LastLogin': FieldValue.serverTimestamp(),
      'Location': location,
      'PhoneNumber': phoneNumber,
      'Rating': 0.0,
      'RegistrationDate': FieldValue.serverTimestamp(),
      'ServiceTypes': serviceTypes,
      'Status': 'Available',
      'TotalJobs': 0,
      'VerificationStatus': 'pending_upload',
      'isAvailable': true,
    }, SetOptions(merge: true));
  }

  /// Update editable fields on the current contractor's document.
  /// Uses [update] so dot-notation keys (e.g. 'ComplianceDocumentsMetadata.ic_front')
  /// are interpreted as nested field paths rather than literal field names.
  Future<void> updateContractorProfile(Map<String, dynamic> data) async {
    final ref = await _myContractorDocRef();
    if (ref == null) throw Exception('Contractor not found');
    await ref.update(data);
  }

  /// Fetch active service names from the Services collection.
  /// Only returns services where Status == 'Active'.
  /// Tries the 'ServiceName' field first, falls back to 'Name', then doc ID.
  /// Throws on failure so callers can display the actual error.
  Future<List<String>> fetchServiceNames() async {
    final snap = await services
        .where('Status', isEqualTo: 'Active')
        .get();
    final names = snap.docs
        .map((doc) {
          final d = doc.data();
          return (d['ServiceName'] ?? d['Name'] ?? doc.id)
              .toString()
              .trim();
        })
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort();
    return names;
  }

  Future<void> setAvailability(bool value) async {
    final ref = await _myContractorDocRef();
    if (ref == null) return;

    // Guard: only verified contractors may go online
    if (value) {
      final snap = await ref.get();
      final status = (snap.data()?['VerificationStatus'] ?? '').toString();
      if (status != 'approved') {
        throw Exception(
          'Cannot go online: your profile is not verified (current status: $status).',
        );
      }
    }

    await ref.set({
      'Status': value ? 'Available' : 'Unavailable',
      'isAvailable': value,
      'LastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateLastLocation(double lat, double lng) async {
    final ref = await _myContractorDocRef();
    if (ref == null) return;

    await ref.set({
      'LastLocation': GeoPoint(lat, lng),
      'LastLocationAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateFcmToken(String token) async {
    final ref = await _myContractorDocRef();
    if (ref == null) return;

    await ref.set({
      'FcmToken': token,
      'FcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists the contractor's push-notification preference to Firestore.
  /// Reads back via [Contractor.notificationsEnabled] / [watchMyContractor].
  /// Throws if the contractor document cannot be resolved (e.g. not signed in).
  Future<void> setNotificationsEnabled(bool enabled) async {
    final ref = await _myContractorDocRef();
    if (ref == null) {
      throw Exception('Contractor profile not found');
    }
    await ref.set({
      'NotificationsEnabled': enabled,
      'NotificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Safely parses a list of job documents. [Job.fromDoc] returns null for
  /// unparseable docs, so we filter those out with [whereType] -- one bad
  /// document never crashes the entire stream.
  List<Job> _safeParseJobs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.map(Job.fromDoc).whereType<Job>().toList();
  }

  /// Watches open jobs (Pending / Bidding) visible to ALL online contractors.
  /// Used by the Inbox page so every contractor can see and bid on requests.
  ///
  /// NOTE: No .orderBy() — avoids requiring a Firestore composite index.
  /// Results are sorted client-side by DateRequested descending.
  /// No .where('ContractorAssigned') ��� open jobs have no contractor yet.
  Stream<List<Job>> watchOpenJobs() {
    debugPrint('🔄 watchOpenJobs() called — fetching Pending & Bidding jobs');

    return jobs
        .where('Status', whereIn: ['Pending', 'Bidding'])
        .limit(50)
        .snapshots()
        .map((snapshot) {
          debugPrint('📊 Open jobs query returned: ${snapshot.docs.length} docs');
          for (final doc in snapshot.docs) {
            final d = doc.data();
            debugPrint('   - ${doc.id}: Status=${d['Status']}, '
                'ServiceType=${d['ServiceType']}, '
                'ContractorAssigned=${d['ContractorAssigned']}');
          }
          final parsed = _safeParseJobs(snapshot.docs);
          // Sort client-side: newest first (avoids composite index requirement)
          parsed.sort((a, b) {
            final aDate = a.dateRequested ?? DateTime(2000);
            final bDate = b.dateRequested ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
          debugPrint('📊 Open jobs after parse: ${parsed.length} jobs');
          return parsed;
        })
        .handleError((error, stackTrace) {
          debugPrint('❌ Error in watchOpenJobs stream: $error');
          debugPrint('   Stack: $stackTrace');
        });
  }

  /// Watches jobs assigned to the current contractor.
  /// Used by the Map page and active-job views (Accepted → InProgress).
  Stream<List<Job>> watchMyJobs() async* {
    debugPrint('🔄 watchMyJobs() called');

    final contractorRef = await _myContractorDocRef();

    if (contractorRef == null) {
      debugPrint('❌ Cannot watch jobs: No contractor reference found');
      yield const <Job>[];
      return;
    }

    debugPrint('✅ Contractor reference: ${contractorRef.id}');
    debugPrint('🔎 Querying jobs where ContractorAssigned = ${contractorRef.path}');

    yield* jobs
        .where('ContractorAssigned', isEqualTo: contractorRef)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          debugPrint('📊 My assigned jobs: ${snapshot.docs.length}');
          final parsed = _safeParseJobs(snapshot.docs);
          // Sort client-side: newest first (avoids composite index requirement)
          parsed.sort((a, b) {
            final aDate = a.dateRequested ?? DateTime(2000);
            final bDate = b.dateRequested ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
          return parsed;
        })
        .handleError((error, stackTrace) {
          debugPrint('❌ Error in watchMyJobs stream: $error');
          debugPrint('   Stack: $stackTrace');
        });
  }

  /// Streams customer reviews from the Jobs collection.
  /// Reviews are stored as UserRating / UserFeedback / UserName fields
  /// on completed Job documents. Filters client-side for jobs where
  /// UserRating > 0, sorted newest-first by DateCompleted.
  Stream<List<Review>> watchContractorReviews() async* {
    final contractorRef = await _myContractorDocRef();
    if (contractorRef == null) {
      yield const [];
      return;
    }
    yield* jobs
        .where('ContractorAssigned', isEqualTo: contractorRef)
        .where('Status', isEqualTo: 'Completed')
        .snapshots()
        .map((snap) {
          final reviews = snap.docs
              .where((doc) {
                final rating = doc.data()['UserRating'];
                return rating != null && rating is num && rating > 0;
              })
              .map(Review.fromJobDoc)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          return reviews;
        });
  }

  Stream<Job?> watchJob(String jobId) {
    return jobs.doc(jobId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Job.fromDoc(snap);
    });
  }

  // Job status updates — bidding / raffle system

  /// Enter a 5-second bidding window for a job. The first contractor to call
  /// this transitions the job from Pending → Bidding and sets the deadline.
  /// Subsequent contractors are added to the bidding pool via arrayUnion.
  Future<void> enterJobBid(String jobId) async {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) throw Exception('Contractor not found');

    // Guard: only verified contractors may bid
    final contractorSnap = await contractors.doc(contractorId).get();
    final vStatus =
        (contractorSnap.data()?['VerificationStatus'] ?? '').toString();
    if (vStatus != 'approved') {
      throw Exception(
        'Cannot bid on job: your profile is not verified (current status: $vStatus).',
      );
    }

    await _db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobs.doc(jobId));
      final data = jobSnap.data();
      if (data == null) throw Exception('Job not found');

      final currentStatus = (data['Status'] ?? '').toString();

      if (currentStatus == 'Pending') {
        // First bidder: transition to Bidding and open the 5-second window
        tx.update(jobs.doc(jobId), {
          'Status': 'Bidding',
          'BiddingContractors': [contractorId],
          'BiddingEndsAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(seconds: 5)),
          ),
        });
      } else if (currentStatus == 'Bidding') {
        // Additional bidder: append to the pool
        tx.update(jobs.doc(jobId), {
          'BiddingContractors': FieldValue.arrayUnion([contractorId]),
        });
      } else {
        throw Exception('Job is no longer accepting bids (status: $currentStatus).');
      }
    });
  }

  /// Legacy entry point — UI still calls this. Delegates to [enterJobBid].
  /// Will be replaced in Phase 2 (UI update) with direct enterJobBid calls.
  Future<void> acceptJob(String jobId) => enterJobBid(jobId);

  /// Assigns the winning contractor after the bidding window closes.
  /// Called by a Cloud Function or client-side timer once [biddingEndsAt] passes.
  Future<void> assignJobWinner(String jobId, String winningUid) async {
    final contractorRef = contractors.doc(winningUid);

    await _db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobs.doc(jobId));
      final data = jobSnap.data();
      if (data == null) throw Exception('Job not found');

      final currentStatus = (data['Status'] ?? '').toString();
      if (currentStatus != 'Bidding') {
        throw Exception('Job is no longer in bidding (status: $currentStatus).');
      }

      tx.update(jobs.doc(jobId), {
        'Status': 'Accepted',
        'ContractorAssigned': contractorRef,
        'DateAccepted': FieldValue.serverTimestamp(),
      });

      // One-job limit: mark this contractor as busy
      tx.update(contractors.doc(winningUid), {
        'ActiveJobId': jobId,
      });
    });
  }

  /// Resolves a bidding window by picking a random winner from the pool.
  /// Safe to call multiple times — silently returns if the job is no longer
  /// in Bidding status (another client already resolved it).
  Future<void> resolveBidding(String jobId) async {
    final rng = Random();

    await _db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobs.doc(jobId));
      final data = jobSnap.data();
      if (data == null) return;

      final currentStatus = (data['Status'] ?? '').toString();
      if (currentStatus != 'Bidding') return; // already resolved

      final bidders = List<String>.from(
        (data['BiddingContractors'] as List?)?.map((e) => e.toString()) ?? [],
      );
      if (bidders.isEmpty) return;

      final winnerUid = bidders[rng.nextInt(bidders.length)];
      final winnerRef = contractors.doc(winnerUid);

      tx.update(jobs.doc(jobId), {
        'Status': 'Accepted',
        'ContractorAssigned': winnerRef,
        'DateAccepted': FieldValue.serverTimestamp(),
      });

      // One-job limit: mark the winner as busy
      tx.update(contractors.doc(winnerUid), {
        'ActiveJobId': jobId,
      });
    });
  }

  Future<void> rejectJob(String jobId) async {
    await jobs.doc(jobId).update({
      'Status': 'Rejected',
      'DateRejected': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final statusText = _toAdminStatus(status);

    final tsField = switch (status) {
      JobStatus.accepted => 'DateAccepted',
      JobStatus.bidding => 'DateBiddingStarted',
      JobStatus.onTheWay => 'DateOnTheWay',
      JobStatus.arrived => 'DateArrived',
      JobStatus.inProgress => 'DateInProgress',
      JobStatus.completed => 'DateCompleted',
      JobStatus.cancelled => 'DateCancelled',
      JobStatus.rejected => 'DateRejected',
      JobStatus.requested => 'DateRequested',
    };

    await jobs.doc(jobId).update({
      'Status': statusText,
      tsField: FieldValue.serverTimestamp(),
    });

    // One-job limit: free the contractor when a job is cancelled
    if (status == JobStatus.cancelled) {
      final contractorId = await getMyContractorDocId();
      if (contractorId != null) {
        await contractors.doc(contractorId).update({
          'ActiveJobId': FieldValue.delete(),
        });
      }
    }
  }

  /// Uploads a proof-of-service photo to Firebase Storage and returns the
  /// download URL. Stored at `job_proofs/{jobId}.jpg`.
  Future<String> uploadProofOfService(String jobId, File imageFile) async {
    final storageRef = FirebaseStorage.instance.ref().child('job_proofs/$jobId.jpg');
    debugPrint('Attempting to upload to: ${storageRef.fullPath}');
    await storageRef.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    return await storageRef.getDownloadURL();
  }

  /// Reference to the invoice counter used for sequential IDs.
  DocumentReference<Map<String, dynamic>> get _invoiceCounterRef =>
      _db.collection('SystemVariables').doc('InvoiceCounter');

  /// Cash payment: writes Job (Completed/Paid), creates JobInvoice, increments
  /// TotalJobs — all in a single Firestore transaction with sequential invoice ID.
  Future<void> finalizeJobCash(
    String jobId,
    double totalCost, {
    String? proofUrl,
    double commission = 0.0,
    double earning = 0.0,
    double walletDelta = 0.0,
  }) async {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) throw Exception('Contractor not found');

    final jobSnap = await jobs.doc(jobId).get();
    final serviceType = (jobSnap.data()?['ServiceType'] ?? '').toString();

    await _db.runTransaction((transaction) async {
      // ── Read & increment the sequential invoice counter ──
      final counterSnap = await transaction.get(_invoiceCounterRef);
      final currentCount =
          counterSnap.exists ? (counterSnap.data()?['count'] ?? 6) as int : 6;
      final newCount = currentCount + 1;
      final newInvoiceId = 'I${newCount.toString().padLeft(3, '0')}';

      transaction.set(_invoiceCounterRef, {'count': newCount});

      // ── Job update ──
      final jobUpdate = <String, dynamic>{
        'Status': 'Completed',
        'TotalCost': totalCost,
        'PaymentMethod': 'Cash',
        'PaymentStatus': 'Paid',
        'Commission': commission,
        'ContractorEarning': earning,
        'DateCompleted': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) jobUpdate['ProofPhotoUrl'] = proofUrl;
      transaction.update(jobs.doc(jobId), jobUpdate);

      // ── Invoice with sequential ID ──
      final invoiceData = <String, dynamic>{
        'JobID': jobId,
        'ContractorID': contractorId,
        'ServiceType': serviceType,
        'TotalCost': totalCost,
        'PaymentMethod': 'Cash',
        'PaymentStatus': 'Paid',
        'Commission': commission,
        'ContractorEarning': earning,
        'RequestedTime': FieldValue.serverTimestamp(),
        'CompletedAt': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) invoiceData['ProofPhotoUrl'] = proofUrl;
      transaction.set(invoices.doc(newInvoiceId), invoiceData);

      // ── Contractor stats ──
      transaction.update(contractors.doc(contractorId), {
        'TotalJobs': FieldValue.increment(1),
        'WalletBalance': FieldValue.increment(walletDelta),
        'ActiveJobId': FieldValue.delete(), // One-job limit: free contractor
      });

      // Ledger: commission deducted from wallet for cash collection
      if (commission > 0) {
        transaction.set(
          contractors.doc(contractorId).collection('transactions').doc(),
          {
            'Amount': commission,
            'Type': 'deduction',
            'Description': 'Platform Commission - Job $jobId',
            'CreatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    });
  }

  /// Online payment: writes Job (Completed/Paid), creates JobInvoice,
  /// increments TotalJobs + wallet — all in a single Firestore transaction
  /// with sequential invoice ID.
  Future<void> finalizeJobOnline(
    String jobId,
    double totalCost, {
    String? proofUrl,
    double commission = 0.0,
    double earning = 0.0,
    double walletDelta = 0.0,
  }) async {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) throw Exception('Contractor not found');

    final jobSnap = await jobs.doc(jobId).get();
    final serviceType = (jobSnap.data()?['ServiceType'] ?? '').toString();

    await _db.runTransaction((transaction) async {
      // ── Read & increment the sequential invoice counter ──
      final counterSnap = await transaction.get(_invoiceCounterRef);
      final currentCount =
          counterSnap.exists ? (counterSnap.data()?['count'] ?? 6) as int : 6;
      final newCount = currentCount + 1;
      final newInvoiceId = 'I${newCount.toString().padLeft(3, '0')}';

      transaction.set(_invoiceCounterRef, {'count': newCount});

      // ── Job update ──
      final jobUpdate = <String, dynamic>{
        'Status': 'Completed',
        'TotalCost': totalCost,
        'PaymentMethod': 'Online',
        'PaymentStatus': 'Paid',
        'Commission': commission,
        'ContractorEarning': earning,
        'DateCompleted': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) jobUpdate['ProofPhotoUrl'] = proofUrl;
      transaction.update(jobs.doc(jobId), jobUpdate);

      // ── Invoice with sequential ID ──
      final invoiceData = <String, dynamic>{
        'JobID': jobId,
        'ContractorID': contractorId,
        'ServiceType': serviceType,
        'TotalCost': totalCost,
        'PaymentMethod': 'Online',
        'PaymentStatus': 'Paid',
        'Commission': commission,
        'ContractorEarning': earning,
        'RequestedTime': FieldValue.serverTimestamp(),
        'CompletedAt': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) invoiceData['ProofPhotoUrl'] = proofUrl;
      transaction.set(invoices.doc(newInvoiceId), invoiceData);

      // ── Contractor stats ──
      transaction.update(contractors.doc(contractorId), {
        'TotalJobs': FieldValue.increment(1),
        'WalletBalance': FieldValue.increment(walletDelta),
        'ActiveJobId': FieldValue.delete(), // One-job limit: free contractor
      });

      // Ledger: earnings credited from online payment
      if (earning > 0) {
        transaction.set(
          contractors.doc(contractorId).collection('transactions').doc(),
          {
            'Amount': earning,
            'Type': 'earning',
            'Description': 'Job Earnings - Job $jobId',
            'CreatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    });
  }

  String _toAdminStatus(JobStatus s) {
    switch (s) {
      case JobStatus.requested:
        return 'Pending';
      case JobStatus.bidding:
        return 'Bidding';
      case JobStatus.accepted:
        return 'Accepted';
      case JobStatus.onTheWay:
        return 'On The Way';
      case JobStatus.arrived:
        return 'Arrived';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
      case JobStatus.rejected:
        return 'Rejected';
    }
  }

  // Chat
  Stream<List<ChatMessage>> watchMessages(String jobId) {
    return jobs
        .doc(jobId)
        .collection('messages')
        .orderBy('CreatedAt', descending: false)
        .limit(200)
        .snapshots()
        .map((q) => q.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage(String jobId, String text) async {
    if (text.trim().isEmpty) return;

    await jobs.doc(jobId).collection('messages').add({
      'SenderId': uid,
      'Text': text.trim(),
      'CreatedAt': FieldValue.serverTimestamp(),
      'IsRead': false,
    });
  }

  /// Streams the count of unread messages from the other party (customer).
  /// A message is "unread" when its senderId differs from the current
  /// contractor's Auth UID and IsRead is not true.
  Stream<int> watchUnreadCount(String jobId) {
    final myUid = uid;
    return jobs
        .doc(jobId)
        .collection('messages')
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
              final d = doc.data();
              final sender =
                  (d['SenderId'] ?? d['senderId'] ?? '').toString();
              final read = d['IsRead'] ?? d['isRead'];
              return sender != myUid && read != true;
            }).length);
  }

  /// Marks all messages from the other party as read in a single batch.
  Future<void> markMessagesAsRead(String jobId) async {
    final myUid = uid;
    final snap = await jobs.doc(jobId).collection('messages').get();

    final batch = _db.batch();
    var count = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      final sender = (d['SenderId'] ?? d['senderId'] ?? '').toString();
      final read = d['IsRead'] ?? d['isRead'];
      if (sender != myUid && read != true) {
        batch.update(doc.reference, {'IsRead': true});
        count++;
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getInvoicesByMonth({
    required String contractorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    debugPrint('💰 getInvoicesByMonth called:');
    debugPrint('   - Contractor: $contractorId');
    debugPrint('   - Start: $startDate');
    debugPrint('   - End: $endDate');

    try {
      final startTs = Timestamp.fromDate(startDate);
      final endTs = Timestamp.fromDate(endDate);

      final query = await invoices
          .where('ContractorID', isEqualTo: contractorId)
          .where('RequestedTime', isGreaterThanOrEqualTo: startTs)
          .where('RequestedTime', isLessThan: endTs)
          .get();

      debugPrint('✅ Query returned ${query.docs.length} invoices');
      return query.docs;
    } catch (e) {
      debugPrint('❌ Query error: $e');
      debugPrint('💡 This might mean:');
      debugPrint('   1. Firestore index is still building (wait 5-10 min)');
      debugPrint('   2. No invoices exist for this contractor');
      debugPrint('   3. Field names are wrong');
      rethrow;
    }
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getMyInvoicesByMonth({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) {
      debugPrint('❌ Cannot get invoices: No contractor ID');
      return [];
    }

    return await getInvoicesByMonth(
      contractorId: contractorId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void clearCache() {
    _cachedContractorDocId = null;
  }

  // ---------------------------------------------------------------------------
  // Withdrawals
  // ---------------------------------------------------------------------------

  /// Creates a withdrawal request and atomically deducts the amount from the
  /// contractor's wallet in a single batch write.
  Future<void> requestWithdrawal({
    required double amount,
    required String bankName,
    required String accountNumber,
    String accountHolderName = '',
  }) async {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) throw Exception('Contractor not found');

    final batch = _db.batch();

    batch.set(withdrawals.doc(), {
      'ContractorID': contractorId,
      'Amount': amount,
      'BankName': bankName,
      'AccountNumber': accountNumber,
      if (accountHolderName.isNotEmpty)
        'AccountHolderName': accountHolderName,
      'Status': 'Pending',
      'RequestedAt': FieldValue.serverTimestamp(),
    });

    batch.update(contractors.doc(contractorId), {
      'WalletBalance': FieldValue.increment(-amount),
    });

    // Ledger: withdrawal deducted from wallet
    batch.set(
      contractors.doc(contractorId).collection('transactions').doc(),
      {
        'Amount': amount,
        'Type': 'withdrawal',
        'Description': 'Withdrawal to $bankName',
        'Status': 'pending',
        'CreatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// Simulates an FPX top-up: logs a Deposit and increments wallet balance.
  Future<void> topUpWallet({required double amount}) async {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) throw Exception('Contractor not found');

    final batch = _db.batch();

    batch.set(_db.collection('Deposits').doc(), {
      'ContractorID': contractorId,
      'Amount': amount,
      'Type': 'TopUp',
      'Method': 'FPX_Simulated',
      'Timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(contractors.doc(contractorId), {
      'WalletBalance': FieldValue.increment(amount),
    });

    // Ledger: top-up credited to wallet
    batch.set(
      contractors.doc(contractorId).collection('transactions').doc(),
      {
        'Amount': amount,
        'Type': 'topup',
        'Description': 'Wallet Top Up (FPX)',
        'CreatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// Streams this contractor's withdrawal history, newest first.
  Stream<List<Map<String, dynamic>>> watchMyWithdrawals() async* {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) {
      yield const [];
      return;
    }

    yield* withdrawals
        .where('ContractorID', isEqualTo: contractorId)
        .orderBy('RequestedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Streams the contractor's unified transaction ledger (earnings, deductions,
  /// top-ups, withdrawals), newest first. Reads from the `transactions`
  /// subcollection under the contractor's document.
  Stream<List<WalletTransaction>> watchMyTransactions() async* {
    final contractorId = await getMyContractorDocId();
    if (contractorId == null) {
      yield const [];
      return;
    }

    yield* contractors
        .doc(contractorId)
        .collection('transactions')
        .orderBy('CreatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => WalletTransaction.fromDoc(d)).toList());
  }
}