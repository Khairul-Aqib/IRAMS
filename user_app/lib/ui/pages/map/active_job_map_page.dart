import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:user_app/services/firestore_service.dart';
import 'package:user_app/services/location_service.dart';
import 'package:user_app/services/routing_service.dart';
import 'package:user_app/services/gps_utils.dart';
import 'package:user_app/models/job.dart';
import 'package:user_app/constants/colors.dart';

enum MapMode {
  activeJob,
  selectCarLocation,
}

class ActiveJobMapPage extends StatefulWidget {
  final MapMode mode;
  final String? jobId;

  const ActiveJobMapPage({
    super.key,
    this.mode = MapMode.activeJob,
    this.jobId,
  });

  @override
  State<ActiveJobMapPage> createState() => _ActiveJobMapPageState();
}

class _ActiveJobMapPageState extends State<ActiveJobMapPage> {
  final MapController _mapController = MapController();
  final GpsSmoothing _gps = GpsSmoothing(alpha: 0.3, maxJumpMeters: 500);

  StreamSubscription? _posSub;
  Timer? _etaTimer;

  LatLng? _my;
  LatLng? _contractorLocation;
  List<LatLng> _route = [];
  Job? _activeJob;

  double _etaSeconds = 0;
  double _distanceMeters = 0;
  bool _locationReady = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    if (widget.mode == MapMode.activeJob) {
      _startEtaTimer();
    }
  }

  // ---------- GPS tracking with smoothing ----------

  Future<void> _startLocationTracking() async {
    final ok = await LocationService.instance.ensurePermission();
    if (!ok) {
      if (mounted) setState(() => _locationReady = true);
      return;
    }

    final p = await LocationService.instance.getCurrent();
    if (p != null) {
      final smoothed = _gps.update(LatLng(p.latitude, p.longitude));
      if (mounted) {
        setState(() {
          _my = smoothed;
          _locationReady = true;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(smoothed, 14);
      });
    } else {
      if (mounted) setState(() => _locationReady = true);
    }

    _posSub = LocationService.instance.watch().listen((pos) async {
      final raw = LatLng(pos.latitude, pos.longitude);
      final smoothed = _gps.update(raw);
      if (mounted) setState(() => _my = smoothed);

      if (widget.mode == MapMode.activeJob) {
        // In user app, we track the user's own location for display.
        // The contractor's location comes from Firestore (via the job stream).
      }
    });
  }

  // ---------- ETA timer — refreshes route + ETA every 10 seconds ----------

  void _startEtaTimer() {
    _etaTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshRouteAndEta();
    });
  }

  Future<void> _refreshRouteAndEta() async {
    final job = _activeJob;
    if (job == null) return;

    // For user tracking: route goes from contractor → user (my location).
    // Contractor location comes from Firestore; user location is _my.
    final from = _contractorLocation;
    final to = _my;

    if (from == null || to == null) return;

    final active = {
      JobStatus.accepted,
      JobStatus.onTheWay,
      JobStatus.inProgress,
    }.contains(job.status);

    if (!active) return;

    try {
      final result = await RoutingService.instance.getRoute(from, to);
      if (!mounted) return;
      setState(() {
        _route = result.polyline;
        _etaSeconds = result.durationSeconds;
        _distanceMeters = result.distanceMeters;
      });
    } catch (_) {
      // OSRM failed — fall back to Haversine estimate
      if (!mounted) return;
      setState(() {
        _etaSeconds = estimateEtaSeconds(from, to);
        _distanceMeters = haversineDistance(from, to);
      });
    }
  }

  /// Read contractor's live location from their Firestore doc.
  Future<void> _updateContractorLocation() async {
    final job = _activeJob;
    if (job == null || job.contractorAssignedRef == null) return;

    try {
      final snap = await job.contractorAssignedRef!.get();
      final data = snap.data();
      if (data is Map<String, dynamic>) {
        final geo = data['LastLocation'];
        if (geo != null) {
          // GeoPoint from Firestore
          final lat = (geo as dynamic).latitude as double;
          final lng = (geo as dynamic).longitude as double;
          if (mounted) {
            setState(() => _contractorLocation = LatLng(lat, lng));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _callUser(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackCenter = const LatLng(3.139, 101.6869);
    final center = _my ?? fallbackCenter;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.user_app',
              ),

              if (widget.mode == MapMode.activeJob && _route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 5,
                      color: kYellow,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // User's location (red dot with glow)
                  if (_my != null)
                    Marker(
                      point: _my!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Contractor's live location (yellow icon)
                  if (widget.mode == MapMode.activeJob && _contractorLocation != null)
                    Marker(
                      point: _contractorLocation!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.local_shipping, color: kYellow, size: 30),
                    ),
                  // Job destination (user's pinned car location from the job)
                  if (widget.mode == MapMode.activeJob &&
                      _activeJob?.userLatLng != null &&
                      _activeJob!.userLatLng != _my)
                    Marker(
                      point: _activeJob!.userLatLng!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // --- ETA overlay ---
          if (widget.mode == MapMode.activeJob && _activeJob != null && _etaSeconds > 0)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _EtaBanner(
                etaSeconds: _etaSeconds,
                distanceMeters: _distanceMeters,
                status: _activeJob!.status.toWire(),
              ),
            ),

          if (!_locationReady)
            const Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _TopToast(text: "Getting location..."),
            ),

          if (widget.mode == MapMode.selectCarLocation)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SelectCarHeader(
                onNext: () {
                  if (_my != null) {
                    Navigator.pop(context, _my);
                  }
                },
              ),
            ),

          if (widget.mode == MapMode.activeJob)
            Align(
              alignment: Alignment.bottomCenter,
              child: StreamBuilder<List<Job>>(
                stream: FirestoreService.instance.watchMyJobs(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _BottomPanelError(
                        error: snap.error.toString());
                  }

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _BottomPanelLoading();
                  }

                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const _BottomPanelEmpty(
                        text: "No active job.");
                  }

                  final jobs = snap.data!;
                  final active = jobs.where((j) => {
                        JobStatus.accepted,
                        JobStatus.onTheWay,
                        JobStatus.inProgress,
                      }.contains(j.status)).toList();

                  final newJob =
                      active.isNotEmpty ? active.first : null;

                  if (_activeJob?.id != newJob?.id ||
                      _activeJob?.status != newJob?.status) {
                    _activeJob = newJob;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await _updateContractorLocation();
                      await _refreshRouteAndEta();
                    });
                  }

                  if (_activeJob == null) {
                    return const _BottomPanelEmpty(
                        text: "No active job.");
                  }

                  final job = _activeJob!;

                  return _UserBottomPanel(
                    job: job,
                    etaText: _etaSeconds > 0 ? formatEta(_etaSeconds) : '--',
                    onCall: job.userPhone.isEmpty
                        ? null
                        : () => _callUser(job.userPhone),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ETA banner overlay
// ---------------------------------------------------------------------------

class _EtaBanner extends StatelessWidget {
  final double etaSeconds;
  final double distanceMeters;
  final String status;

  const _EtaBanner({
    required this.etaSeconds,
    required this.distanceMeters,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final eta = formatEta(etaSeconds);
    final dist = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${distanceMeters.round()} m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: kYellow, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Arriving in $eta',
                  style: const TextStyle(
                    color: kYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                eta,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Text(dist, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User-side bottom panel (shows contractor info + ETA)
// ---------------------------------------------------------------------------

class _UserBottomPanel extends StatelessWidget {
  final Job job;
  final String etaText;
  final VoidCallback? onCall;

  const _UserBottomPanel({
    required this.job,
    required this.etaText,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.serviceType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${job.status.toWire()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kYellow),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ETA', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      etaText,
                      style: const TextStyle(
                        color: kYellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onCall,
              icon: const Icon(Icons.phone, size: 18),
              label: const Text(
                'Call Contractor',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets (unchanged)
// ---------------------------------------------------------------------------

class _SelectCarHeader extends StatelessWidget {
  final VoidCallback onNext;

  const _SelectCarHeader({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      color: const Color(0xFF1A1A1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WHERE'S YOUR CAR?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Move the map to adjust the pin",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: onNext,
              child: const Text(
                'NEXT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopToast extends StatelessWidget {
  final String text;
  const _TopToast({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text("Getting location...")),
        ],
      ),
    );
  }
}

class _BottomPanelLoading extends StatelessWidget {
  const _BottomPanelLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BottomPanelEmpty extends StatelessWidget {
  final String text;
  const _BottomPanelEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF1A1A1A),
      child: Text(text),
    );
  }
}

class _BottomPanelError extends StatelessWidget {
  final String error;
  const _BottomPanelError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF1A1A1A),
      child: Text(error, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
