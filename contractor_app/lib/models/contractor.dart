import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

// =============================================================================
// Compliance document metadata (per-document status object)
// =============================================================================

class ComplianceDoc {
  final String url;
  final String? expiry; // ISO-8601 date string or null
  final String status; // 'uploaded' | 'approved' | 'rejected' | 'expired'
  final String? rejectionReason;

  const ComplianceDoc({
    required this.url,
    this.expiry,
    this.status = 'uploaded',
    this.rejectionReason,
  });

  factory ComplianceDoc.fromMap(Map<String, dynamic> m) {
    return ComplianceDoc(
      url: (m['url'] ?? '').toString(),
      expiry: m['expiry']?.toString(),
      status: (m['status'] ?? 'uploaded').toString(),
      rejectionReason: m['rejectionReason']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        if (expiry != null) 'expiry': expiry,
        'status': status,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };
}

// =============================================================================
// Contractor model
// =============================================================================

class Contractor {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final bool isAvailable;
  final double rating;
  final LatLng? lastLocation;
  final String status; // "Available" / "Unavailable"
  final int totalJobs;
  final String verificationStatus; // pending_upload | under_review | approved | rejected
  final String selfieStatus; // uploaded | verified (dedicated, not tied to global)
  final String accountStatus; // "Active" / "Suspended"
  final bool notificationsEnabled;
  final double walletBalance;

  // Bank details
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolderName;

  // Profile image (set by Admin after approving the submitted selfie)
  final String? approvedProfileImageUrl;

  // Currently active job (one-job-at-a-time enforcement)
  final String? activeJobId;

  // Compliance documents metadata (keyed by doc slug e.g. 'ic_front', 'gdl_license')
  final Map<String, ComplianceDoc> complianceDocumentsMetadata;

  Contractor({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isAvailable,
    required this.rating,
    required this.lastLocation,
    required this.status,
    required this.totalJobs,
    required this.verificationStatus,
    this.selfieStatus = '',
    required this.accountStatus,
    required this.notificationsEnabled,
    required this.walletBalance,
    this.approvedProfileImageUrl,
    this.activeJobId,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountHolderName,
    this.complianceDocumentsMetadata = const {},
  });

  // ── Convenience accessors ───────────��─────────────────────��────────────────

  bool get isBankVerified =>
      bankName != null &&
      bankName!.isNotEmpty &&
      bankAccountNumber != null &&
      bankAccountNumber!.isNotEmpty;

  bool get hasActiveJob =>
      activeJobId != null && activeJobId!.isNotEmpty;

  bool get hasPendingCriticalDocument =>
      complianceDocumentsMetadata.values
          .any((doc) => doc.status == 'rejected' || doc.status == 'expired');

  // ── Parsing ─────────────────��─────────────────────────────────��────────────

  static Contractor fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    LatLng? ll;
    final gp = d['LastLocation'] as GeoPoint?; // PascalCase!
    if (gp != null) ll = LatLng(gp.latitude, gp.longitude);

    // Parse compliance documents metadata map
    Map<String, ComplianceDoc> complianceDocs = {};
    final rawCompliance = d['ComplianceDocumentsMetadata'];
    if (rawCompliance is Map) {
      complianceDocs = rawCompliance.map((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key.toString(), ComplianceDoc.fromMap(value));
        }
        // Fallback: if value is just a URL string (legacy simple map)
        if (value is String && value.isNotEmpty) {
          return MapEntry(
            key.toString(),
            ComplianceDoc(url: value, status: 'uploaded'),
          );
        }
        return MapEntry(
          key.toString(),
          const ComplianceDoc(url: '', status: 'uploaded'),
        );
      });
    }

    return Contractor(
      uid: doc.id,
      fullName: (d['FullName'] ?? 'Contractor').toString(), // PascalCase
      email: (d['Email'] ?? '').toString(),
      phone: (d['PhoneNumber'] ?? '').toString(), // PhoneNumber not phone
      isAvailable: (d['Status'] ?? '').toString().toLowerCase() == 'available',
      rating: (d['Rating'] is num) ? (d['Rating'] as num).toDouble() : 0.0,
      lastLocation: ll,
      status: (d['Status'] ?? 'Unavailable').toString(),
      totalJobs: (d['TotalJobs'] is num) ? (d['TotalJobs'] as num).toInt() : 0,
      verificationStatus:
          (d['VerificationStatus'] ?? 'pending_upload').toString(),
      selfieStatus: (d['SelfieStatus'] ?? '').toString(),
      accountStatus: (d['AccountStatus'] ?? 'Active').toString(),
      // Default to true so existing contractors keep receiving alerts until
      // they explicitly opt out from the Settings page.
      notificationsEnabled: (d['NotificationsEnabled'] is bool)
          ? d['NotificationsEnabled'] as bool
          : true,
      walletBalance: (d['WalletBalance'] is num)
          ? (d['WalletBalance'] as num).toDouble()
          : 0.0,
      approvedProfileImageUrl: d['ApprovedProfileImageUrl']?.toString(),
      activeJobId: d['ActiveJobId']?.toString(),
      bankName: d['BankName']?.toString(),
      bankAccountNumber: d['BankAccountNumber']?.toString(),
      bankAccountHolderName: d['BankAccountHolderName']?.toString(),
      complianceDocumentsMetadata: complianceDocs,
    );
  }

  Map<String, dynamic> toMap() => {
        'FullName': fullName,
        'Email': email,
        'PhoneNumber': phone,
        'Status': status,
        'Rating': rating,
        'TotalJobs': totalJobs,
        'VerificationStatus': verificationStatus,
        if (selfieStatus.isNotEmpty) 'SelfieStatus': selfieStatus,
        'AccountStatus': accountStatus,
        'NotificationsEnabled': notificationsEnabled,
        'WalletBalance': walletBalance,
        'isAvailable': isAvailable, // convenience field for app
        if (approvedProfileImageUrl != null)
          'ApprovedProfileImageUrl': approvedProfileImageUrl,
        if (activeJobId != null) 'ActiveJobId': activeJobId,
        if (bankName != null) 'BankName': bankName,
        if (bankAccountNumber != null) 'BankAccountNumber': bankAccountNumber,
        if (bankAccountHolderName != null)
          'BankAccountHolderName': bankAccountHolderName,
        if (complianceDocumentsMetadata.isNotEmpty)
          'ComplianceDocumentsMetadata': complianceDocumentsMetadata
              .map((key, doc) => MapEntry(key, doc.toMap())),
      };
}
