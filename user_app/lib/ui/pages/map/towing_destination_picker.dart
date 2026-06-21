import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;

import 'package:user_app/ui/pages/map/location_picker_page.dart';

/// Lets the user pick a towing destination on the map, calculates distance
/// from the breakdown location, and shows a live total cost.
///
/// Returns a [PickedLocation] via Navigator.pop when 'NEXT' is pressed.
class TowingDestinationPickerPage extends StatefulWidget {
  /// Where the car currently is (breakdown spot).
  final LatLng breakdownLocation;

  /// Hook-up / base fee (e.g. RM 50).
  final double basePrice;

  /// Label for the service (e.g. "Tyres – Towing").
  final String serviceType;

  /// Human-readable address of the breakdown location.
  final String? breakdownAddress;

  /// Firestore GeoPoint of the breakdown location.
  final GeoPoint? breakdownGeo;

  const TowingDestinationPickerPage({
    super.key,
    required this.breakdownLocation,
    required this.basePrice,
    required this.serviceType,
    this.breakdownAddress,
    this.breakdownGeo,
  });

  @override
  State<TowingDestinationPickerPage> createState() =>
      _TowingDestinationPickerPageState();
}

class _TowingDestinationPickerPageState
    extends State<TowingDestinationPickerPage> {
  GoogleMapController? _mapController;
  String? _darkStyle;

  late LatLng _center;
  String _address = 'Move the map to set destination';
  bool _loadingAddress = false;

  double _distanceKm = 0;
  double _totalCost = 0;

  /// Per-km rate.
  static const double _ratePerKm = 5.0;

  Timer? _debounce;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<_SearchResult> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _center = widget.breakdownLocation;
    _totalCost = widget.basePrice;
    _loadMapStyle();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Map style ──────────────────────────────────────────────────────────

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/map_style_dark.json');
    if (mounted) setState(() => _darkStyle = style);
  }

  // ── Camera / geocode ───────────────────────────────────────────────────

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _reverseGeocode(_center);
      _recalculate();
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty);
        setState(() {
          _address =
              parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
          _loadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = 'Could not resolve address';
          _loadingAddress = false;
        });
      }
    }
  }

  // ── Distance & pricing ─────────────────────────────────────────────────

  void _recalculate() {
    final meters = Geolocator.distanceBetween(
      widget.breakdownLocation.latitude,
      widget.breakdownLocation.longitude,
      _center.latitude,
      _center.longitude,
    );
    final km = meters / 1000.0;
    setState(() {
      _distanceKm = km;
      _totalCost = widget.basePrice + (km * _ratePerKm);
    });
  }

  // ── Search ─────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    try {
      final locations = await geo.locationFromAddress(query);
      if (!mounted || locations.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _searching = false;
          });
        }
        return;
      }

      final results = <_SearchResult>[];
      for (final loc in locations) {
        try {
          final placemarks = await geo.placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = [
              p.name,
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea,
            ].where((s) => s != null && s.isNotEmpty).toSet();
            results.add(_SearchResult(
              address: parts.isNotEmpty ? parts.join(', ') : query,
              latLng: LatLng(loc.latitude, loc.longitude),
            ));
          }
        } catch (_) {
          results.add(_SearchResult(
            address: query,
            latLng: LatLng(loc.latitude, loc.longitude),
          ));
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
    }
  }

  void _selectSearchResult(_SearchResult result) {
    _searchCtrl.text = result.address;
    _searchFocus.unfocus();
    setState(() {
      _searchResults = [];
      _center = result.latLng;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(result.latLng, 17),
    );
    _reverseGeocode(result.latLng);
    _recalculate();
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _onNext() {
    Navigator.pop(
      context,
      PickedLocation(
        latLng: _center,
        addressName: _address,
        geoPoint: GeoPoint(_center.latitude, _center.longitude),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _darkStyle,
            onMapCreated: (c) => _mapController = c,
            onCameraMove: _onCameraMove,
          ),

          // ── Center pin (red for towing destination) ──
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: Colors.red,
              ),
            ),
          ),

          // Pin shadow
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // ── Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Title card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WHERE ARE YOU TOWING TO?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pin your location or input an address',
                              style:
                                  TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child:
                            Icon(Icons.search, color: Colors.white38, size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search for a destination...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon:
                              const Icon(Icons.close, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          },
                        ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.yellow,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Search results dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on,
                              color: Colors.yellow, size: 20),
                          title: Text(
                            result.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── My-location FAB ──
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton.small(
              heroTag: 'myLocTow',
              backgroundColor: const Color(0xFF1E1E1E),
              onPressed: () async {
                try {
                  final pos = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                    ),
                  );
                  final ll = LatLng(pos.latitude, pos.longitude);
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(ll, 17),
                  );
                } catch (_) {}
              },
              child: const Icon(Icons.my_location, color: Colors.yellow),
            ),
          ),

          // ── Bottom card ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Towing destination address
                  const Text(
                    'TOWING DESTINATION',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_pin,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _loadingAddress
                            ? const Text(
                                'Resolving address...',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              )
                            : Text(
                                _address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Distance & pricing summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distance: ${_distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'RM ${_totalCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // NEXT button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _onNext,
                      child: const Text(
                        'NEXT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String address;
  final LatLng latLng;

  const _SearchResult({required this.address, required this.latLng});
}
