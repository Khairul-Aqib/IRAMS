import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/payment.dart';
import 'user_firestore_service.dart';

/// Manages JobInvoice documents in Firestore.
///
/// Field naming uses PascalCase to match the Admin Panel's expectations,
/// with additional camelCase aliases for Contractor App compatibility.
///
/// Admin Panel reads: TotalCost, ServiceType, ContractorID, UserID,
///   PaymentMethod, Status, UserLocation, RequestedTime, StartTime,
///   CompletionTime, UserRating, Cancellation
///
/// Contractor App reads: contractorId, totalCost, serviceType, createdAt
class InvoiceService {
  InvoiceService._();
  static final instance = InvoiceService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  String get uid => _user?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get invoices =>
      _db.collection('JobInvoice');

  /// Platform fee rate (15% — matches Admin Panel and Contractor App).
  static const double platformFeeRate = 0.15;

  /// Create a JobInvoice document after successful FPX payment.
  ///
  /// This writes fields compatible with BOTH:
  ///  - Admin Panel (PascalCase: TotalCost, ContractorID, PaymentMethod, etc.)
  ///  - Contractor App (camelCase: totalCost, contractorId, createdAt, etc.)
  Future<String> createInvoice({
    required String jobId,
    required String serviceType,
    required double totalCost,
    required String userLocation,
    required FpxTransaction fpxTxn,
    String? contractorId,
    String? batteryModel,
    String? warranty,
    GeoPoint? userGeo,
  }) async {
    final now = FieldValue.serverTimestamp();
    final platformFee = (totalCost * platformFeeRate).roundToDouble();
    final contractorEarnings = totalCost - platformFee;

    // Fetch user contact details and friendly ID from profile
    final contactDetails =
        await UserFirestoreService.instance.getUserContactDetails();
    final friendlyId =
        await UserFirestoreService.instance.getCustomUserId();

    final userPath = '/Users/$friendlyId';
    final receiptNo = 'IRAMS-${DateTime.now().millisecondsSinceEpoch}';
    final fpxData = fpxTxn.toFirestore();

    final data = <String, dynamic>{
      // ── Admin Panel fields (PascalCase) ──
      'JobID': jobId,
      'ServiceType': serviceType,
      'TotalCost': totalCost,
      'PlatformFee': platformFee,
      'ContractorEarnings': contractorEarnings,
      'PaymentMethod': 'FPX',
      'Status': 'Completed',
      'UserID': userPath,
      'ContractorID': contractorId ?? '',
      'UserLocation': userLocation,
      'UserName': contactDetails['UserName'],
      'UserPhone': contactDetails['UserPhone'],
      if (userGeo != null) 'UserGeo': userGeo,
      'RequestedTime': now,
      'CompletionTime': now,
      'UserRating': null,
      'Cancellation': '',
      if (batteryModel != null) 'BatteryModel': batteryModel,
      if (warranty != null) 'Warranty': warranty,
      'FpxTransaction': fpxData,
      'ReceiptNo': receiptNo,
      'Currency': 'MYR',

      // ── Contractor App / camelCase aliases (audit-mandated mirror) ──
      'jobId': jobId,
      'serviceType': serviceType,
      'totalCost': totalCost,
      'platformFee': platformFee,
      'contractorEarnings': contractorEarnings,
      'paymentMethod': 'FPX',
      'status': 'Completed',
      'userId': userPath,
      'contractorId': contractorId ?? '',
      'userLocation': userLocation,
      'userName': contactDetails['UserName'],
      'userPhone': contactDetails['UserPhone'],
      if (userGeo != null) 'userGeo': userGeo,
      'requestedTime': now,
      'completionTime': now,
      'userRating': null,
      'cancellation': '',
      if (batteryModel != null) 'batteryModel': batteryModel,
      if (warranty != null) 'warranty': warranty,
      'fpxTransaction': fpxData,
      'receiptNo': receiptNo,
      'currency': 'MYR',
      'createdAt': now,
    };

    final docRef = await invoices.add(data);
    return docRef.id;
  }

  /// Update an existing invoice when a contractor completes the job.
  /// Called from the Contractor App flow when job status → Completed.
  Future<void> markCompleted({
    required String invoiceId,
    required String contractorId,
    DateTime? startTime,
  }) async {
    final startTs = startTime != null
        ? Timestamp.fromDate(startTime)
        : FieldValue.serverTimestamp();
    final completeTs = FieldValue.serverTimestamp();

    await invoices.doc(invoiceId).set({
      // PascalCase (Admin)
      'Status': 'Completed',
      'ContractorID': contractorId,
      'StartTime': startTs,
      'CompletionTime': completeTs,
      // camelCase aliases (Contractor App)
      'status': 'Completed',
      'contractorId': contractorId,
      'startTime': startTs,
      'completionTime': completeTs,
    }, SetOptions(merge: true));
  }

  /// Fetch a single invoice by ID (for receipt display).
  Future<Map<String, dynamic>?> getInvoice(String invoiceId) async {
    final snap = await invoices.doc(invoiceId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...snap.data()!};
  }

  /// Fetch all invoices for the current user (for history page).
  Future<List<Map<String, dynamic>>> getMyInvoices() async {
    final friendlyId =
        await UserFirestoreService.instance.getCustomUserId();
    final userPath = '/Users/$friendlyId';
    final qs = await invoices
        .where('UserID', isEqualTo: userPath)
        .orderBy('createdAt', descending: true)
        .get();

    return qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
