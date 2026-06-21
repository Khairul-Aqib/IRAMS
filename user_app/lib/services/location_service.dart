import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final instance = LocationService._();

  Future<bool> ensurePermission() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      perm = await Geolocator.checkPermission();
    }

    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<Position?> getCurrent() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    // `desiredAccuracy` is deprecated in newer geolocator versions.
    // Use locationSettings instead.
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Stream<Position> watch() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
