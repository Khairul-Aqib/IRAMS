import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum JobStatus {
  requested,
  bidding,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  completed,
  cancelled,
  rejected,
}

extension JobStatusWire on JobStatus {
  /// Matches Firestore `Status` strings (matches screenshots)
  String toWire() {
    switch (this) {
      case JobStatus.requested:
        return 'Pending'; // Firebase shows "Pending"
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

  static JobStatus fromWire(String? s) {
    final v = (s ?? '').trim().toLowerCase();
    if (v == 'pending') return JobStatus.requested;
    if (v == 'bidding') return JobStatus.bidding;
    if (v == 'accepted') return JobStatus.accepted;
    if (v == 'on the way' || v == 'ontheway') return JobStatus.onTheWay;
    if (v == 'arrived') return JobStatus.arrived;
    if (v == 'in progress' || v == 'inprogress') return JobStatus.inProgress;
    if (v == 'completed') return JobStatus.completed;
    if (v == 'cancelled' || v == 'canceled') return JobStatus.cancelled;
    if (v == 'rejected') return JobStatus.rejected;
    return JobStatus.requested;
  }
}

class Job {
  final String id;
  final String jobId;
  final String serviceType;
  final JobStatus status;
  final double totalCost;
  final String userLocation;

  // References
  final DocumentReference? userRef;
  final DocumentReference? contractorAssignedRef;

  /// Raw string identifier of ContractorAssigned regardless of stored type.
  /// If the Firestore value is a DocumentReference, this holds its `.id`.
  /// If it is a plain String, this holds that string directly.
  /// Empty when the field is absent or null.
  final String contractorAssignedRaw;

  // Date fields
  final DateTime? dateRequested;
  final DateTime? dateAccepted;
  final DateTime? dateRejected;
  final DateTime? dateOnTheWay;
  final DateTime? dateArrived;
  final DateTime? dateInProgress;
  final DateTime? dateCompleted;
  final DateTime? dateCancelled;

  // Location
  final LatLng? userLatLng;
  final LatLng? contractorGeo;

  // Denormalized user data
  final String userName;
  final String userPhone;

  // Optional fields
  final String description;
  final Map<String, dynamic>? vehicleInfo;
  final String paymentStatus;
  final String paymentMethod;

  // Bidding / raffle fields
  final List<String> biddingContractors;
  final DateTime? biddingEndsAt;

  Job({
    required this.id,
    required this.jobId,
    required this.serviceType,
    required this.status,
    required this.totalCost,
    required this.userLocation,
    this.userRef,
    this.contractorAssignedRef,
    this.contractorAssignedRaw = '',
    this.dateRequested,
    this.dateAccepted,
    this.dateRejected,
    this.dateOnTheWay,
    this.dateArrived,
    this.dateInProgress,
    this.dateCompleted,
    this.dateCancelled,
    this.userLatLng,
    this.contractorGeo,
    this.userName = '',
    this.userPhone = '',
    this.description = '',
    this.vehicleInfo,
    this.paymentStatus = 'Pending',
    this.paymentMethod = '',
    this.biddingContractors = const [],
    this.biddingEndsAt,
  });

  // ---------------------------------------------------------------------------
  // Parsing helpers (static, so they can be used before the constructor call)
  // ---------------------------------------------------------------------------

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static LatLng? _geo(dynamic v) {
    if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
    return null;
  }

  /// Safe number -> double.  Firestore may store int (e.g. 50) or
  /// double (50.0); a strict `as double` on an int would crash.
  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// ContractorAssigned may be a DocumentReference, a String path/UID, or null.
  static DocumentReference? _parseRef(dynamic v) {
    if (v == null) return null;
    if (v is DocumentReference) return v;
    if (v is String && v.trim().isNotEmpty) {
      try {
        return FirebaseFirestore.instance.doc(v.trim());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Returns a raw string identifier regardless of stored type.
  static String _rawRefId(dynamic v) {
    if (v == null) return '';
    if (v is DocumentReference) return v.id;
    if (v is String) return v.trim();
    return v.toString();
  }

  /// BiddingContractors may be null, a List, or absent entirely.
  static List<String> _parseBidders(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// VehicleInfo may be null, a Map<String,dynamic>, or a raw Map.
  static Map<String, dynamic>? _parseVehicleInfo(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      try {
        return Map<String, dynamic>.from(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // fromDoc  --  returns null on failure so a single bad document never
  //              crashes the entire stream.
  // ---------------------------------------------------------------------------

  static Job? fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    try {
      final d = snap.data() ?? {};

      return Job(
        id: snap.id,
        jobId: _str(d['JobID'], snap.id),
        serviceType: _str(d['ServiceType'], 'Unknown Service'),
        status: JobStatusWire.fromWire(d['Status']?.toString()),
        totalCost: _toDouble(d['TotalCost']),
        userLocation: _str(
          d['UserLocation'] ?? d['userLocation'] ?? d['Address'] ?? d['address'],
          'Location details not provided',
        ),

        // References -- accept both DocumentReference and raw String
        userRef: d['UserID'] is DocumentReference
            ? d['UserID'] as DocumentReference
            : null,
        contractorAssignedRef: _parseRef(d['ContractorAssigned']),
        contractorAssignedRaw: _rawRefId(d['ContractorAssigned']),

        // Date fields
        dateRequested: _dt(d['DateRequested']),
        dateAccepted: _dt(d['DateAccepted']),
        dateRejected: _dt(d['DateRejected']),
        dateOnTheWay: _dt(d['DateOnTheWay']),
        dateArrived: _dt(d['DateArrived']),
        dateInProgress: _dt(d['DateInProgress']),
        dateCompleted: _dt(d['DateCompleted']),
        dateCancelled: _dt(d['DateCancelled']),

        // Location
        userLatLng: _geo(d['UserGeo'] ?? d['userGeo'] ?? d['Location'] ?? d['location']),
        contractorGeo: _geo(d['ContractorGeo'] ?? d['contractorGeo']),

        // Denormalized data
        userName: _str(d['UserName']),
        userPhone: _str(d['UserPhone']),

        // Optional fields
        description: _str(d['Description']),
        vehicleInfo: _parseVehicleInfo(d['VehicleInfo']),
        paymentStatus: _str(d['PaymentStatus'], 'Pending'),
        paymentMethod: _str(d['PaymentMethod']),

        // Bidding fields
        biddingContractors: _parseBidders(d['BiddingContractors']),
        biddingEndsAt: _dt(d['BiddingEndsAt']),
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('\u{1F525} ERROR PARSING JOB ${snap.id}: $e');
      // ignore: avoid_print
      print('   Stack: $stack');
      return null;
    }
  }

  /// Convert to map for Firestore updates
  Map<String, dynamic> toMap() => {
    'JobID': jobId,
    'ServiceType': serviceType,
    'Status': status.toWire(),
    'TotalCost': totalCost,
    'UserLocation': userLocation,
    if (userRef != null) 'UserID': userRef,
    if (contractorAssignedRef != null) 'ContractorAssigned': contractorAssignedRef,
    if (dateRequested != null) 'DateRequested': Timestamp.fromDate(dateRequested!),
    if (dateAccepted != null) 'DateAccepted': Timestamp.fromDate(dateAccepted!),
    if (dateRejected != null) 'DateRejected': Timestamp.fromDate(dateRejected!),
    if (dateOnTheWay != null) 'DateOnTheWay': Timestamp.fromDate(dateOnTheWay!),
    if (dateArrived != null) 'DateArrived': Timestamp.fromDate(dateArrived!),
    if (dateInProgress != null) 'DateInProgress': Timestamp.fromDate(dateInProgress!),
    if (dateCompleted != null) 'DateCompleted': Timestamp.fromDate(dateCompleted!),
    if (dateCancelled != null) 'DateCancelled': Timestamp.fromDate(dateCancelled!),
    if (userLatLng != null) 'UserGeo': GeoPoint(userLatLng!.latitude, userLatLng!.longitude),
    if (contractorGeo != null) 'ContractorGeo': GeoPoint(contractorGeo!.latitude, contractorGeo!.longitude),
    'UserName': userName,
    'UserPhone': userPhone,
    if (description.isNotEmpty) 'Description': description,
    if (vehicleInfo != null) 'VehicleInfo': vehicleInfo,
    'PaymentStatus': paymentStatus,
    if (paymentMethod.isNotEmpty) 'PaymentMethod': paymentMethod,
    if (biddingContractors.isNotEmpty) 'BiddingContractors': biddingContractors,
    if (biddingEndsAt != null) 'BiddingEndsAt': Timestamp.fromDate(biddingEndsAt!),
  };

  /// Copy with method for easy updates
  Job copyWith({
    String? id,
    String? jobId,
    String? serviceType,
    JobStatus? status,
    double? totalCost,
    String? userLocation,
    DocumentReference? userRef,
    DocumentReference? contractorAssignedRef,
    String? contractorAssignedRaw,
    DateTime? dateRequested,
    DateTime? dateAccepted,
    DateTime? dateRejected,
    DateTime? dateOnTheWay,
    DateTime? dateArrived,
    DateTime? dateInProgress,
    DateTime? dateCompleted,
    DateTime? dateCancelled,
    LatLng? userLatLng,
    LatLng? contractorGeo,
    String? userName,
    String? userPhone,
    String? description,
    Map<String, dynamic>? vehicleInfo,
    String? paymentStatus,
    String? paymentMethod,
    List<String>? biddingContractors,
    DateTime? biddingEndsAt,
  }) {
    return Job(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      serviceType: serviceType ?? this.serviceType,
      status: status ?? this.status,
      totalCost: totalCost ?? this.totalCost,
      userLocation: userLocation ?? this.userLocation,
      userRef: userRef ?? this.userRef,
      contractorAssignedRef: contractorAssignedRef ?? this.contractorAssignedRef,
      contractorAssignedRaw: contractorAssignedRaw ?? this.contractorAssignedRaw,
      dateRequested: dateRequested ?? this.dateRequested,
      dateAccepted: dateAccepted ?? this.dateAccepted,
      dateRejected: dateRejected ?? this.dateRejected,
      dateOnTheWay: dateOnTheWay ?? this.dateOnTheWay,
      dateArrived: dateArrived ?? this.dateArrived,
      dateInProgress: dateInProgress ?? this.dateInProgress,
      dateCompleted: dateCompleted ?? this.dateCompleted,
      dateCancelled: dateCancelled ?? this.dateCancelled,
      userLatLng: userLatLng ?? this.userLatLng,
      contractorGeo: contractorGeo ?? this.contractorGeo,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      description: description ?? this.description,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      biddingContractors: biddingContractors ?? this.biddingContractors,
      biddingEndsAt: biddingEndsAt ?? this.biddingEndsAt,
    );
  }

  /// Check if this job has a contractor assigned (ref or raw string)
  bool get hasContractor =>
      contractorAssignedRef != null || contractorAssignedRaw.isNotEmpty;

  /// Check if this job is available for contractors to accept
  bool get isAvailable => status == JobStatus.requested && !hasContractor;

  /// Creates an updated job when a contractor accepts it
  Job acceptedBy(DocumentReference contractorRef) {
    return copyWith(
      status: JobStatus.accepted,
      contractorAssignedRef: contractorRef,
      dateAccepted: DateTime.now(),
    );
  }

  /// Validate if status transition is allowed
  bool canTransitionTo(JobStatus newStatus) {
    // Can't accept a job that already has a contractor
    if (newStatus == JobStatus.accepted && hasContractor) {
      return false;
    }

    // Can only progress if contractor is assigned (except for requested/cancelled)
    if (newStatus != JobStatus.requested &&
        newStatus != JobStatus.cancelled &&
        !hasContractor) {
      return false;
    }

    return true;
  }
}
