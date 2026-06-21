import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class Contractor {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final bool isAvailable;
  final double rating;
  final LatLng? lastLocation;

  Contractor({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isAvailable,
    required this.rating,
    required this.lastLocation,
  });

  static Contractor fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    LatLng? ll;
    final gp = d['lastLocation'] as GeoPoint?;
    if (gp != null) ll = LatLng(gp.latitude, gp.longitude);

    return Contractor(
      uid: doc.id,
      fullName: (d['fullName'] ?? 'Contractor').toString(),
      email: (d['email'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString(),
      isAvailable: (d['isAvailable'] ?? false) == true,
      rating: (d['rating'] is num) ? (d['rating'] as num).toDouble() : 0.0,
      lastLocation: ll,
    );
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'isAvailable': isAvailable,
        'rating': rating,
      };
}
