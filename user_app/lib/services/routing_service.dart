import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Result from an OSRM route request, containing the polyline,
/// estimated duration (seconds), and distance (meters).
class RouteResult {
  final List<LatLng> polyline;
  final double durationSeconds;
  final double distanceMeters;

  const RouteResult({
    required this.polyline,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  static const empty = RouteResult(polyline: [], durationSeconds: 0, distanceMeters: 0);
}

class RoutingService {
  RoutingService._();
  static final instance = RoutingService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  /// Uses OSRM public demo server (OK for prototype).
  /// Returns polyline points, duration, and distance.
  Future<RouteResult> getRoute(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    final resp = await _dio.get(url);
    final routes = resp.data['routes'] as List?;
    if (routes == null || routes.isEmpty) return RouteResult.empty;

    final route = routes.first;
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final duration = (route['duration'] as num?)?.toDouble() ?? 0;
    final distance = (route['distance'] as num?)?.toDouble() ?? 0;

    return RouteResult(
      polyline: polyline,
      durationSeconds: duration,
      distanceMeters: distance,
    );
  }

  /// Legacy helper that returns only the polyline (for existing callers).
  Future<List<LatLng>> getRoutePolyline(LatLng from, LatLng to) async {
    final result = await getRoute(from, to);
    return result.polyline;
  }
}
