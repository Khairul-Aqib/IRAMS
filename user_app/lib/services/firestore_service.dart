import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/job.dart';
import '../models/contractor.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get user => FirebaseAuth.instance.currentUser;
  String get uid => user?.uid ?? '';

  // Cache contractor doc id (e.g. "C001") after first lookup
  String? _cachedContractorDocId;

  CollectionReference<Map<String, dynamic>> get contractors =>
      _db.collection('Contractor'); // PascalCase (matches your screenshot)

  CollectionReference<Map<String, dynamic>> get jobs =>
      _db.collection('Jobs'); // PascalCase

  CollectionReference<Map<String, dynamic>> get invoices =>
      _db.collection('JobInvoice');

  // ---------------------------------------------------------------------------
  // Contractor lookups
  // ---------------------------------------------------------------------------

  /// Public: direct contractor document ref by ContractorID doc id (e.g. "C001")
  DocumentReference<Map<String, dynamic>> contractorDocRef(
    String contractorId,
  ) {
    return contractors.doc(contractorId);
  }

  /// Return my contractor docId ("C001") by email. Caches the result.
  Future<String?> getMyContractorDocId() async {
    if (_cachedContractorDocId != null) return _cachedContractorDocId;

    final u = user;
    final email = (u?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return null;

    final q = await contractors.where('Email', isEqualTo: email).limit(1).get();
    if (q.docs.isEmpty) return null;

    _cachedContractorDocId = q.docs.first.id;
    return _cachedContractorDocId;
  }

  /// Internal: get my contractor doc ref (C001 etc) using email
  Future<DocumentReference<Map<String, dynamic>>?> _myContractorDocRef() async {
    final id = await getMyContractorDocId();
    if (id == null) return null;
    return contractorDocRef(id);
  }

  /// Stream my contractor profile doc (by Email -> doc id)
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
    await contractors.doc(contractorId).set({
      'AccountStatus': 'Active',
      'CompanyContactPhone': companyContactPhone,
      'CompanyName': companyName,
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
      'VerificationStatus': 'Pending',

      // extra fields ok (won't break admin)
      'isAvailable': true,
    }, SetOptions(merge: true));
  }

  /// Toggle availability — keep admin field `Status`
  Future<void> setAvailability(bool value) async {
    final ref = await _myContractorDocRef();
    if (ref == null) return;

    await ref.set({
      'Status': value ? 'Available' : 'Unavailable',
      'isAvailable': value, // extra convenience for app
      'LastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Save contractor GPS location (extra fields, won't break admin)
  Future<void> updateLastLocation(double lat, double lng) async {
    final ref = await _myContractorDocRef();
    if (ref == null) return;

    await ref.set({
      'LastLocation': GeoPoint(lat, lng),
      'LastLocationAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Save contractor FCM token (extra field, won't break admin)
  Future<void> updateFcmToken(String token) async {
    final ref = await _myContractorDocRef();
    if (ref == null) return;

    await ref.set({
      'fcmToken': token,
      'FcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Job>> watchMyJobs() async* {
    final contractorRef = await _myContractorDocRef();
    if (contractorRef == null) {
      yield const <Job>[];
      return;
    }

    yield* jobs
        .where('ContractorAssigned', isEqualTo: contractorRef)
        .orderBy('DateRequested', descending: true)
        .limit(50)
        .snapshots()
        .map((q) => q.docs.map(Job.fromDoc).toList());
  }

  Stream<Job?> watchJob(String jobId) {
    return jobs.doc(jobId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Job.fromDoc(snap);
    });
  }

  /// Accept job: set Status field (admin style)
  Future<void> acceptJob(String jobId) async {
    await jobs.doc(jobId).set({
      'Status': 'Accepted',
      'DateAccepted': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Reject job
  Future<void> rejectJob(String jobId) async {
    await jobs.doc(jobId).set({
      'Status': 'Rejected',
      'DateRejected': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Generic update job status: write admin-friendly status strings
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final statusText = _toAdminStatus(status);

    final tsField = switch (status) {
      JobStatus.awaitingPayment => 'DateBillCreated',
      JobStatus.accepted => 'DateAccepted',
      JobStatus.onTheWay => 'DateOnTheWay',
      JobStatus.arrived => 'DateArrived',
      JobStatus.inProgress => 'DateInProgress',
      JobStatus.completed => 'DateCompleted',
      JobStatus.cancelled => 'DateCancelled',
      JobStatus.rejected => 'DateRejected',
      JobStatus.requested => 'DateRequested',
      JobStatus.unknown => 'DateUnknown',
    };

    await jobs.doc(jobId).set({
      'Status': statusText,
      tsField: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _toAdminStatus(JobStatus s) => s.toWire();
}
