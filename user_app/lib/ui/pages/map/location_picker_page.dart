import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;

/// Data returned when the user confirms a location.
class PickedLocation {
  final LatLng latLng;
  final String addressName;
  final GeoPoint geoPoint;

  const PickedLocation({
    required this.latLng,
    required this.addressName,
    required this.geoPoint,
  });
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  String? _darkStyle;

  // Default: Bukit Bintang, KL
  static const LatLng _fallback = LatLng(3.1466, 101.7101);

  LatLng _center = _fallback;
  String _address = 'Move the map to set location';
  bool _loadingAddress = false;
  bool _locatingUser = true;

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
    _loadMapStyle();
    _goToUserLocation();
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

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/map_style_dark.json');
    setState(() => _darkStyle = style);
  }

  Future<void> _goToUserLocation() async {
    setState(() => _locatingUser = true);

    try {
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _locatingUser = false);
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _locatingUser = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final userLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = userLatLng;
        _locatingUser = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userLatLng, 17),
      );
      _reverseGeocode(userLatLng);
    } catch (_) {
      setState(() => _locatingUser = false);
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _reverseGeocode(_center);
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

  // --- Search ---

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
        if (mounted) setState(() { _searchResults = []; _searching = false; });
        return;
      }

      // Reverse-geocode each result to get a human-readable address.
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
            ].where((s) => s != null && s.isNotEmpty).toSet(); // toSet removes dupes
            results.add(_SearchResult(
              address: parts.isNotEmpty ? parts.join(', ') : query,
              latLng: LatLng(loc.latitude, loc.longitude),
            ));
          }
        } catch (_) {
          // Fallback: use the query text itself
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
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      PickedLocation(
        latLng: _center,
        addressName: _address,
        geoPoint: GeoPoint(_center.latitude, _center.longitude),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- Google Map ---
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // we have our own
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _darkStyle,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: _onCameraMove,
          ),

          // --- Center pin overlay ---
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: Colors.yellow,
              ),
            ),
          ),

          // --- Pin shadow dot ---
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

          // --- Loading indicator while getting user location ---
          if (_locatingUser)
            const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            ),

          // --- Search bar ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search for a location...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
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
                      border: Border.all(
                        color: const Color(0xFF2A2A2A),
                      ),
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
                          leading: const Icon(
                            Icons.location_on,
                            color: Colors.yellow,
                            size: 20,
                          ),
                          title: Text(
                            result.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // --- My-location FAB ---
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton.small(
              heroTag: 'myLoc',
              backgroundColor: const Color(0xFF1E1E1E),
              onPressed: _goToUserLocation,
              child: const Icon(Icons.my_location, color: Colors.yellow),
            ),
          ),

          // --- Bottom address card + confirm button ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_pin,
                          color: Colors.yellow, size: 20),
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
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _confirmLocation,
                      child: const Text(
                        'Confirm Breakdown Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
