import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:user_app/services/location_service.dart';
import 'package:user_app/constants/colors.dart';
import 'package:user_app/ui/pages/payment/payment_confirmation.dart';

class CarTowMapPage extends StatefulWidget {
  final String serviceRequested;
  final double totalAmount;

  const CarTowMapPage({
    super.key,
    required this.serviceRequested,
    required this.totalAmount,
  });

  @override
  State<CarTowMapPage> createState() => _CarTowMapPageState();
}

class _CarTowMapPageState extends State<CarTowMapPage> {
  final MapController _mapController = MapController();

  StreamSubscription? _posSub;
  LatLng? _myLocation;
  LatLng? _selectedDestination;

  bool _locationReady = false;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  Future<void> _startLocation() async {
    final ok = await LocationService.instance.ensurePermission();
    if (!ok) {
      if (mounted) setState(() => _locationReady = true);
      return;
    }

    final pos = await LocationService.instance.getCurrent();
    if (pos != null && mounted) {
      final ll = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _myLocation = ll;
        _selectedDestination = ll;
        _locationReady = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(ll, 13);
      });
    }

    _posSub = LocationService.instance.watch().listen((pos) {
      if (!mounted) return;
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  void _onNextPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationPage(
          serviceRequested: widget.serviceRequested,
          totalAmount: widget.totalAmount,
          userGeo: _selectedDestination != null
              ? GeoPoint(_selectedDestination!.latitude, _selectedDestination!.longitude)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = const LatLng(3.1390, 101.6869);
    final center = _selectedDestination ?? _myLocation ?? fallback;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          /// MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              maxZoom: 19,
              onPositionChanged: (pos, _) {
                _selectedDestination = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.user_app',
              ),
              if (_selectedDestination != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedDestination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          /// HEADER (BLACK – matches screenshot)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
              color: const Color(0xFF121212),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "WHERE ARE YOU TOWING TO?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Pin your location or input an address",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          /// CENTER PIN
          const Center(
            child: IgnorePointer(
              child: Icon(
                Icons.add_location_alt,
                size: 36,
                color: Colors.redAccent,
              ),
            ),
          ),

          /// BOTTOM BAR
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOWING DESTINATION',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kuala Lumpur, Wilayah Persekutuan Kuala Lumpur',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: _onNextPressed,
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

          if (!_locationReady)
            Positioned(top: 120, left: 16, right: 16, child: _TopToast()),
        ],
      ),
    );
  }
}

class _TopToast extends StatelessWidget {
  const _TopToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.yellow,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Getting location...",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
