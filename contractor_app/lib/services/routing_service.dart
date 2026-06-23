import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

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
  Future<List<LatLng>> getRoutePolyline(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson';
    final resp = await _dio.get(url);
    final routes = resp.data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];
    final coords = routes.first['geometry']['coordinates'] as List;
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }
}
