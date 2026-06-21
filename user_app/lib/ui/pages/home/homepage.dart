import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:user_app/ui/pages/map/active_job_map_page.dart';
import 'package:user_app/ui/pages/map/active_job_tracking.dart';
import 'package:user_app/ui/pages/requestJob/select_car.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/ui/pages/home/emergency_call.dart';
import 'package:user_app/ui/pages/home/history.dart';
import 'package:user_app/ui/pages/home/car_list.dart';
import 'package:user_app/models/unread_menu_button.dart';
import 'package:user_app/services/user_firestore_service.dart';
import 'package:user_app/ui/pages/home/notification.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _jobsSub;

  LatLng? _myLocation;
  bool _mapReady = false;
  bool _hasActiveJob = false;
  String? _activeJobId;
  String? _userPath;
  String? _customId;

  /// Tracks the last-seen status per job so we only fire notifications on
  /// actual transitions, not on initial load or duplicate snapshots.
  final Map<String, String> _lastSeenStatus = {};

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _resolveUserAndWatchJobs();
  }

  Future<void> _resolveUserAndWatchJobs() async {
    final customId = await UserFirestoreService.instance.getCustomUserId();
    if (!mounted || customId.isEmpty) return;
    setState(() {
      _customId = customId;
      _userPath = '/Users/$customId';
    });
    _watchActiveJobs();
  }

  void _watchActiveJobs() {
    if (_userPath == null) return;

    _jobsSub?.cancel();
    _jobsSub = FirebaseFirestore.instance
        .collection('Jobs')
        .where('UserID', isEqualTo: _userPath)
        .where('Status', whereIn: [
          'Pending',
          'Accepted',
          'OnTheWay',
          'Arrived',
          'InProgress',
          'Completed',
        ])
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      // ── Detect status changes and create notifications ──
      for (final doc in snap.docs) {
        final jobId = doc.id;
        final status = (doc.data()['Status'] ?? '').toString();
        final prev = _lastSeenStatus[jobId];

        if (prev != null && prev != status && _customId != null) {
          final serviceType = (doc.data()['ServiceType'] ?? '').toString();
          createJobNotification(
            friendlyId: _customId!,
            jobId: jobId,
            newStatus: status,
            serviceType: serviceType.isNotEmpty ? serviceType : null,
          );
        }

        _lastSeenStatus[jobId] = status;
      }

      // ── Update UI state for the "Track Request" bar ──
      // Pick the first non-Completed job for display, if any.
      final activeDoc = snap.docs
          .where((d) => d.data()['Status'] != 'Completed')
          .toList();

      setState(() {
        _hasActiveJob = activeDoc.isNotEmpty;
        _activeJobId = activeDoc.isNotEmpty ? activeDoc.first.id : null;
      });
    });
  }

  void _moveMap(LatLng target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _mapController.move(target, 14);
    });
  }

  Future<void> _startLocationTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final initial = LatLng(pos.latitude, pos.longitude);
    setState(() => _myLocation = initial);

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = ll);
      _moveMap(ll);
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .snapshots();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fallback = LatLng(3.1390, 101.6869);
    final center = _myLocation ?? fallback;

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        leading: const UnreadMenuButton(),
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final name = data?['fullName'] ??
                data?['firstName'] ??
                FirebaseAuth.instance.currentUser?.displayName ??
                '';
            return Text(
              name.toString().isNotEmpty ? 'Hello, $name!' : 'Hello!',
              style: const TextStyle(color: Colors.white),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we assist you today?',
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 16),

            // ── Mini Map ──
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _activeJobId != null
                        ? ActiveJobTrackingPage(jobId: _activeJobId!)
                        : const ActiveJobMapPage(),
                  ),
                );
              },
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                      onMapReady: () {
                        _mapReady = true;
                        if (_myLocation != null) {
                          _moveMap(_myLocation!);
                        }
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.user_app',
                      ),
                      if (_myLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _myLocation!,
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Primary action: Request Help / Track Current Request ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (_hasActiveJob && _activeJobId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ActiveJobTrackingPage(jobId: _activeJobId!),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SelectCarPage()),
                    );
                  }
                },
                icon: Icon(
                  _hasActiveJob ? Icons.location_on : Icons.build,
                  size: 20,
                ),
                label: Text(
                  _hasActiveJob ? 'Track Current Request' : 'Request Help',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Emergency ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EmergencyCallPage()),
                  );
                },
                icon: const Icon(Icons.sos, size: 20),
                label: const Text(
                  'Emergency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Bottom Grid: My Vehicles & History ──
            Row(
              children: [
                Expanded(
                  child: _squareTile(
                    icon: Icons.directions_car,
                    label: 'My Vehicles',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CarListPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _squareTile(
                    icon: Icons.receipt_long,
                    label: 'History',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HistoryPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _squareTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: Colors.yellow),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
