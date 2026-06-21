import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart';

class UserFirestoreService {
  UserFirestoreService._();
  static final instance = UserFirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  String get uid => _user?.uid ?? '';

  // ---------------------------------------------------------------------------
  // Custom User ID (e.g. U001) — cached after first lookup
  // ---------------------------------------------------------------------------

  String? _cachedCustomId;

  /// Generate the next auto-incrementing UserID (e.g. U001, U002, …)
  /// inside a Firestore transaction to prevent duplicates.
  Future<String> generateNextUserId() async {
    final counterRef = _db.collection('Metadata').doc('Counters');

    return _db.runTransaction<String>((txn) async {
      final counterSnap = await txn.get(counterRef);
      int lastNumber = 0;

      if (counterSnap.exists) {
        lastNumber = (counterSnap.data()?['lastUserNumber'] ?? 0) as int;
      }

      final nextNumber = lastNumber + 1;
      final customId = 'U${nextNumber.toString().padLeft(3, '0')}';

      txn.set(counterRef, {'lastUserNumber': nextNumber}, SetOptions(merge: true));

      return customId;
    });
  }

  /// Look up the custom UserID (U***) for the currently logged-in user by
  /// querying `Users` for the doc whose `authUid` field matches.
  /// Returns an empty string if no document is linked to this auth user.
  Future<String> getCustomUserId() async {
    if (_cachedCustomId != null) return _cachedCustomId!;
    if (uid.isEmpty) return '';

    final qs = await _db
        .collection('Users')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (qs.docs.isNotEmpty) {
      _cachedCustomId = qs.docs.first.id;
      return _cachedCustomId!;
    }

    return '';
  }

  /// Clear cached custom ID (call on logout).
  void clearCache() => _cachedCustomId = null;

  /// Stamp `lastLogin` on the current user's U*** doc with a server timestamp.
  /// Safe to call from any sign-in path — uses the cached custom ID lookup
  /// and silently no-ops if the user isn't linked yet, so it can never block
  /// the login flow.
  Future<void> touchLastLogin() async {
    try {
      final customId = await getCustomUserId();
      if (customId.isEmpty) return;
      await _db.collection('Users').doc(customId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Audit field — never block login on a write failure.
    }
  }

  /// Fetch the current user's Name and Phone from the linked U*** doc.
  Future<Map<String, String>> getUserContactDetails() async {
    try {
      final customId = await getCustomUserId();
      Map<String, dynamic>? data;
      if (customId.isNotEmpty) {
        final doc = await _db.collection('Users').doc(customId).get();
        data = doc.data();
      }

      final name = (data?['fullName'] as String?) ?? '';
      final phone = (data?['phone'] as String?) ?? '';

      return {
        'UserName': name.isNotEmpty
            ? name
            : _user?.displayName ?? _user?.email ?? 'Unknown User',
        'UserPhone': phone.isNotEmpty ? phone : '',
      };
    } catch (_) {
      return {
        'UserName': _user?.displayName ?? _user?.email ?? 'Unknown User',
        'UserPhone': '',
      };
    }
  }

  CollectionReference<Map<String, dynamic>> get jobs =>
      _db.collection('Jobs');

  /// Create a new roadside assistance job. UserID stored as `/Users/U***`.
  Future<String> createJob({
    required LatLng carLocation,
    required String carPlate,
    required String serviceType,
    double totalCost = 0,
    String userLocation = '',
  }) async {
    final friendlyId = await getCustomUserId();
    final userPath = '/Users/$friendlyId';
    final doc = await jobs.add({
      'UserID': userPath,
      'ownerAuthUid': uid,
      'CarPlate': carPlate,
      'ServiceType': serviceType,
      'Status': 'Pending',
      'TotalCost': totalCost,
      'UserLocation': userLocation,
      'CarLocation': GeoPoint(
        carLocation.latitude,
        carLocation.longitude,
      ),
      'UserGeo': GeoPoint(
        carLocation.latitude,
        carLocation.longitude,
      ),
      'UserName': _user?.displayName ?? '',
      'UserPhone': '',
      'DateRequested': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Watch all jobs created by this user.
  /// Requires the friendly ID (e.g. U001) to build the /Users/ path.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyJobs(String friendlyId) {
    final userPath = '/Users/$friendlyId';
    return jobs
        .where('UserID', isEqualTo: userPath)
        .orderBy('DateRequested', descending: true)
        .snapshots();
  }

  /// Watch a single job
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchJob(String jobId) {
    return jobs.doc(jobId).snapshots();
  }

  /// Update car location (live tracking)
  Future<void> updateCarLocation(
    String jobId,
    LatLng location,
  ) async {
    await jobs.doc(jobId).set({
      'CarLocation': GeoPoint(
        location.latitude,
        location.longitude,
      ),
      'LastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Cancel job
  Future<void> cancelJob(String jobId) async {
    await jobs.doc(jobId).set({
      'Status': 'Cancelled',
      'DateCancelled': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Vehicles — top-level CarDetails collection
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get carDetails =>
      _db.collection('CarDetails');

  /// Real-time stream of the current user's vehicles by custom UserID.
  /// Consumers should filter `IsDeleted == true` docs (see [isVehicleDeleted])
  /// so that soft-deleted entries stay queryable for the Admin while staying
  /// hidden from the user.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyVehicles(String customUserId) {
    return carDetails
        .where('OwnerID', isEqualTo: customUserId)
        .snapshots();
  }

  /// True if a CarDetails doc has been soft-deleted.
  static bool isVehicleDeleted(Map<String, dynamic>? data) =>
      data != null && data['IsDeleted'] == true;

  /// Add a new vehicle to the top-level CarDetails collection.
  /// Document ID = CarID_{NumberPlate}.
  Future<String> addVehicle({
    required String ownerID,
    required String make,
    required String model,
    required String year,
    required String numberPlate,
  }) async {
    final plate = numberPlate.toUpperCase();
    final docId = 'CarID_$plate';

    await carDetails.doc(docId).set({
      'OwnerID': ownerID,
      'Make': make,
      'Model': model,
      'Year': year,
      'NumberPlate': plate,
      'CreatedAt': FieldValue.serverTimestamp(),
    });

    return docId;
  }

  /// Update an existing vehicle in CarDetails.
  Future<void> updateVehicle({
    required String vehicleId,
    required String ownerID,
    required String make,
    required String model,
    required String year,
    required String numberPlate,
  }) async {
    final plate = numberPlate.toUpperCase();
    final newDocId = 'CarID_$plate';

    // If the plate changed, the doc ID changes — delete old and create new
    if (newDocId != vehicleId) {
      await carDetails.doc(vehicleId).delete();
      await carDetails.doc(newDocId).set({
        'OwnerID': ownerID,
        'Make': make,
        'Model': model,
        'Year': year,
        'NumberPlate': plate,
        'CreatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await carDetails.doc(vehicleId).update({
        'Make': make,
        'Model': model,
        'Year': year,
        'NumberPlate': plate,
      });
    }
  }

  /// Soft-delete a vehicle from CarDetails.
  /// Sets `IsDeleted: true` and stamps `DeletedAt` so the Admin can audit and
  /// (if needed) restore the record. The doc is NOT removed from Firestore.
  Future<void> deleteVehicle(String vehicleId) async {
    await carDetails.doc(vehicleId).set({
      'IsDeleted': true,
      'DeletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Add a vehicle whose brand is not in the CarBrands catalog.
  /// Make is forced to 'Undefined' so admins can flag it for review;
  /// the user-typed brand and model are preserved alongside.
  Future<String> addUndefinedVehicle({
    required String ownerID,
    required String manualBrand,
    required String manualModel,
    required String year,
    required String numberPlate,
    String? supportTicketId,
  }) async {
    final plate = numberPlate.toUpperCase();
    final docId = 'CarID_$plate';

    await carDetails.doc(docId).set({
      'OwnerID': ownerID,
      'Make': 'Undefined',
      'Model': manualModel,
      'ManualBrandName': manualBrand,
      'ManualModelName': manualModel,
      'Year': year,
      'NumberPlate': plate,
      if (supportTicketId != null) 'SupportTicketID': supportTicketId,
      'CreatedAt': FieldValue.serverTimestamp(),
    });

    return docId;
  }

  // ---------------------------------------------------------------------------
  // Car brand catalog (read-only)
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get carBrandsCollection =>
      _db.collection('CarBrands');

  /// Fetch every brand once. Each entry contains the brand `name` (doc id)
  /// and its `models` list pulled from the `CarTypes` array field.
  Future<List<CarBrand>> fetchCarBrands() async {
    final snap = await carBrandsCollection.get();
    final brands = snap.docs.map((d) {
      final data = d.data();
      final raw = data['CarTypes'];
      final models = raw is List
          ? raw.map((e) => e.toString()).toList()
          : <String>[];
      return CarBrand(name: d.id, models: models);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return brands;
  }

  // ---------------------------------------------------------------------------
  // Vehicle requests — created when a user submits an unknown brand/model
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get vehicleRequests =>
      _db.collection('VehicleRequests');

  /// Upload the selected request photo to Firebase Storage and return its
  /// download URL. Path: vehicle_requests/{uid}_{epoch_ms}.jpg.
  Future<String> uploadVehicleRequestImage({required File file}) async {
    if (uid.isEmpty) {
      throw StateError('Must be signed in to upload a vehicle request photo.');
    }
    final filename = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('vehicle_requests/$filename');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Create a `VehicleRequests` document an admin will review.
  /// `requestType` distinguishes the two flows: 'New Brand' vs 'New Model'.
  Future<String> createVehicleRequest({
    required String brandName,
    required String modelName,
    required String requestType,
    String? imageUrl,
  }) async {
    final doc = await vehicleRequests.add({
      'brandName': brandName,
      'modelName': modelName,
      'requestType': requestType,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'userId': uid,
      'ownerAuthUid': uid,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}

/// Lightweight value object for a brand pulled from the `CarBrands` catalog.
class CarBrand {
  final String name;
  final List<String> models;
  const CarBrand({required this.name, required this.models});
}
