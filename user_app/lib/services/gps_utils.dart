import 'dart:math';
import 'package:latlong2/latlong.dart';

/// GPS location smoothing using an exponential moving average (low-pass filter).
///
/// Raw GPS readings can jump erratically due to satellite signal fluctuations,
/// urban canyon reflections, or brief loss of fix. This filter blends each new
/// reading with the previous smoothed position:
///
///   smoothed = alpha * raw + (1 - alpha) * previous
///
/// A spike guard rejects any single update that exceeds [maxJumpMeters],
/// treating it as a GPS glitch rather than real movement.
class GpsSmoothing {
  /// Smoothing factor: 0.0 = ignore new data, 1.0 = no smoothing.
  /// 0.3 gives a good balance between responsiveness and jitter reduction.
  final double alpha;

  /// Maximum distance (meters) a single GPS update can jump before it's
  /// considered a spike and discarded.
  final double maxJumpMeters;

  LatLng? _smoothed;

  GpsSmoothing({this.alpha = 0.3, this.maxJumpMeters = 500});

  /// Feed a raw GPS reading and get back the smoothed position.
  LatLng update(LatLng raw) {
    final prev = _smoothed;

    // First reading — accept as-is.
    if (prev == null) {
      _smoothed = raw;
      return raw;
    }

    // Spike guard: reject unreasonably large jumps.
    final dist = haversineDistance(prev, raw);
    if (dist > maxJumpMeters) {
      return prev;
    }

    // Exponential moving average on each axis independently.
    final lat = alpha * raw.latitude + (1 - alpha) * prev.latitude;
    final lng = alpha * raw.longitude + (1 - alpha) * prev.longitude;

    _smoothed = LatLng(lat, lng);
    return _smoothed!;
  }

  /// Reset the filter (e.g. when starting a new tracking session).
  void reset() => _smoothed = null;

  /// The most recent smoothed position, or null if no data yet.
  LatLng? get current => _smoothed;
}

// ---------------------------------------------------------------------------
// Haversine distance & ETA helpers
// ---------------------------------------------------------------------------

/// Haversine distance between two coordinates, in meters.
double haversineDistance(LatLng a, LatLng b) {
  const R = 6371000.0; // Earth radius in meters
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final sinLat = sin(dLat / 2);
  final sinLng = sin(dLng / 2);
  final h = sinLat * sinLat +
      cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sinLng * sinLng;
  return 2 * R * asin(sqrt(h));
}

double _rad(double deg) => deg * pi / 180;

/// Estimate driving ETA in seconds from straight-line distance.
///
/// Uses [speedKmh] as the assumed average urban driving speed (default 35 km/h)
/// and a [detourFactor] to account for road network indirection (default 1.4).
///
/// This is a fallback — prefer OSRM duration when available.
double estimateEtaSeconds(LatLng from, LatLng to, {double speedKmh = 35, double detourFactor = 1.4}) {
  final meters = haversineDistance(from, to) * detourFactor;
  final speedMs = speedKmh * 1000 / 3600;
  return meters / speedMs;
}

/// Format seconds into a human-readable ETA string.
String formatEta(double seconds) {
  if (seconds < 60) return '< 1 min';
  final mins = (seconds / 60).round();
  if (mins < 60) return '$mins min${mins == 1 ? '' : 's'}';
  final h = mins ~/ 60;
  final m = mins % 60;
  return '${h}h ${m}m';
}
