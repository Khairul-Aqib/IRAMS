import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum JobStatus {
  awaitingPayment,
  requested,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  completed,
  cancelled,
  rejected,
  unknown,
}

extension JobStatusWire on JobStatus {
  /// Matches your Firestore `Status` strings (Pascal Case)
  String toWire() {
    switch (this) {
      case JobStatus.awaitingPayment:
        return 'Awaiting Payment';
      case JobStatus.requested:
        return 'Pending';
      case JobStatus.accepted:
        return 'Accepted';
      case JobStatus.onTheWay:
        return 'OnTheWay';
      case JobStatus.arrived:
        return 'Arrived';
      case JobStatus.inProgress:
        return 'InProgress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
      case JobStatus.rejected:
        return 'Rejected';
      case JobStatus.unknown:
        return '';
    }
  }

  static JobStatus fromWire(String? s) {
    final v = (s ?? '').trim().toLowerCase();
    if (v.isEmpty) return JobStatus.unknown;
    if (v == 'awaiting payment' || v == 'awaitingpayment') {
      return JobStatus.awaitingPayment;
    }
    if (v == 'pending') return JobStatus.requested;
    if (v == 'accepted') return JobStatus.accepted;
    if (v == 'on the way' || v == 'ontheway') return JobStatus.onTheWay;
    if (v == 'arrived') return JobStatus.arrived;
    if (v == 'in progress' || v == 'inprogress') return JobStatus.inProgress;
    if (v == 'completed') return JobStatus.completed;
    if (v == 'cancelled' || v == 'canceled') return JobStatus.cancelled;
    if (v == 'rejected') return JobStatus.rejected;
    return JobStatus.unknown;
  }
}

class Job {
  final String id;
  final String jobId;
  final String serviceType;
  final JobStatus status;
  final num totalCost;
  final String userLocation;

  final DocumentReference? userRef;
  final DocumentReference? contractorAssignedRef;

  final DateTime? dateRequested;
  final DateTime? dateCompleted;

  final LatLng? userLatLng;

  final String userName;
  final String userPhone;

  final String? toyyibPayBillCode;

  Job({
    required this.id,
    required this.jobId,
    required this.serviceType,
    required this.status,
    required this.totalCost,
    required this.userLocation,
    required this.userRef,
    required this.contractorAssignedRef,
    required this.dateRequested,
    required this.dateCompleted,
    required this.userLatLng,
    required this.userName,
    required this.userPhone,
    this.toyyibPayBillCode,
  });

  static Job fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? {};

    DateTime? dt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    LatLng? geo(dynamic v) {
      if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
      return null;
    }

    return Job(
      id: snap.id,
      jobId: (d['JobID'] ?? snap.id).toString(),
      serviceType: (d['ServiceType'] ?? '').toString(),
      status: JobStatusWire.fromWire(d['Status']?.toString()),
      totalCost: (d['TotalCost'] is num) ? d['TotalCost'] as num : num.tryParse('${d['TotalCost']}') ?? 0,
      userLocation: (d['UserLocation'] ?? '').toString(),

      userRef: d['UserID'] is DocumentReference ? d['UserID'] as DocumentReference : null,
      contractorAssignedRef: d['ContractorAssigned'] is DocumentReference ? d['ContractorAssigned'] as DocumentReference : null,

      dateRequested: dt(d['DateRequested']),
      dateCompleted: dt(d['DateCompleted']),

      userLatLng: geo(d['UserGeo']),
      userName: (d['UserName'] ?? '').toString(),
      userPhone: (d['UserPhone'] ?? '').toString(),
      toyyibPayBillCode: (d['ToyyibPayBillCode'] as String?)?.trim().isEmpty == false
          ? (d['ToyyibPayBillCode'] as String)
          : null,
    );
  
  }
}
