import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:slide_to_act/slide_to_act.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../../services/routing_service.dart';
import '../../../models/job.dart';
import '../../../core/theme.dart';
import '../chat/chat_page.dart';
import '../jobs/job_details_page.dart';
import '../../widgets/app_loader.dart';

class ActiveJobMapPage extends StatefulWidget {
  const ActiveJobMapPage({super.key});

  @override
  State<ActiveJobMapPage> createState() => _ActiveJobMapPageState();
}

class _ActiveJobMapPageState extends State<ActiveJobMapPage> {
  final Completer<GoogleMapController> _mapCompleter =
      Completer<GoogleMapController>();
  final _slideKey = GlobalKey<SlideActionState>();

  /// Direct handle to the GoogleMapController once the map has been built.
  /// Populated in `onMapCreated` alongside the Completer. This field is what
  /// the custom "my location" FAB path uses so the spec-exact nullable
  /// `_mapController!.animateCamera(...)` pattern is available without
  /// having to `await` the Completer on every tap.
  GoogleMapController? _mapController;

  StreamSubscription? _posSub;
  ll.LatLng? _my;
  List<ll.LatLng> _route = [];
  Job? _activeJob;

  bool _locationReady = false;
  bool _isProcessing = false;
  DateTime? _lastLocationWrite;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  /// Checks and requests the runtime location permission via the geolocator
  /// package (delegated through `LocationService.instance.ensurePermission()`
  /// so the flow stays consistent with the rest of the app).
  ///
  /// Returns `true` if the contractor has granted at least `whileInUse`
  /// permission and location services are on, `false` otherwise. The
  /// underlying service also opens the OS Location Settings page when
  /// services are off, and the App Settings page on `deniedForever`, so the
  /// caller here does not need to handle those edge cases directly.
  Future<bool> _checkLocationPermission() {
    return LocationService.instance.ensurePermission();
  }

  /// Snaps the map camera to the contractor's current GPS position at a
  /// comfortable street-level zoom (15.0). Used by BOTH:
  ///   - the custom "my location" FAB (manual tap)
  ///   - the `onMapCreated` auto-locate path when there is no active job
  ///
  /// Note: `desiredAccuracy:` is deprecated in geolocator 13.x — we pass
  /// `locationSettings: LocationSettings(accuracy: LocationAccuracy.high)`
  /// which is the modern equivalent and matches the rest of this codebase
  /// (see `LocationService.getCurrent()`).
  Future<void> _centerOnCurrentLocation() async {
    try {
      // Don't bother hitting GPS hardware if we haven't got permission yet.
      final ok = await _checkLocationPermission();
      if (!ok) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Guard: widget could have been disposed while the GPS call was
      // in flight, and the controller might not be ready yet if the user
      // somehow triggered this before `onMapCreated` fired.
      if (!mounted) return;
      if (_mapController == null) return;

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15.0,
        ),
      );
    } catch (e) {
      debugPrint('Failed to center on current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get your current location.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final ok = await _checkLocationPermission();
      if (!ok) {
        if (mounted) {
          setState(() => _locationReady = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Map features may be limited.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final p = await LocationService.instance.getCurrent();
      if (p != null) {
        final point = ll.LatLng(p.latitude, p.longitude);
        if (mounted) {
          setState(() {
            _my = point;
            _locationReady = true;
          });
        }
        // Note: Intentionally NOT panning camera to my location on init —
        // the spec wants the camera focused on the stranded user's coords.
      } else {
        if (mounted) setState(() => _locationReady = true);
      }

      _posSub = LocationService.instance.watch().listen(
        (pos) async {
          final point = ll.LatLng(pos.latitude, pos.longitude);
          if (mounted) setState(() => _my = point);

          await _syncLocationThrottled(point);
          await _refreshRoute();

          // AUTO-LOCATE: keep the contractor centered on the map while they
          // are actively driving toward the stranded user. We only do this
          // during the `onTheWay` phase — once they arrive on-site we stop
          // recentering so the operator can freely pan around the scene
          // with both the stranded user pin AND their own blue dot visible.
          if (!mounted) return;
          if (_activeJob?.status == JobStatus.onTheWay) {
            await _moveCamera(point, zoom: 16);
          }
        },
        onError: (e) {
          debugPrint('Location stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start location tracking: $e');
      if (mounted) {
        setState(() => _locationReady = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access location services. Please check your settings.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Writes the contractor's location to Firestore, gated by:
  ///   1. Job must be in an active tracking status (accepted / onTheWay / arrived / inProgress).
  ///   2. At most one write every 10 seconds (spec requirement).
  ///
  /// The stream from LocationService already applies a 10m distanceFilter, so a
  /// position event is only emitted after the contractor has physically moved ≥10m.
  /// Combined with this 10s time gate we match the spec exactly.
  Future<void> _syncLocationThrottled(ll.LatLng point) async {
    final job = _activeJob;
    if (job == null) return;

    const trackingStatuses = {
      JobStatus.accepted,
      JobStatus.onTheWay,
      JobStatus.arrived,
      JobStatus.inProgress,
    };
    if (!trackingStatuses.contains(job.status)) return;

    final now = DateTime.now();
    if (_lastLocationWrite != null &&
        now.difference(_lastLocationWrite!).inSeconds < 10) {
      return;
    }

    _lastLocationWrite = now;
    try {
      await FirestoreService.instance
          .updateLastLocation(point.latitude, point.longitude);
    } catch (e) {
      // Non-fatal: skip this sync, the next throttled write will retry.
      debugPrint('Failed to sync location to Firestore: $e');
    }
  }

  Future<void> _refreshRoute() async {
    final job = _activeJob;
    final my = _my;
    // Abort immediately if there is no active job, no GPS fix, or no user
    // destination — guards the force-unwrap on job.userLatLng below AND
    // prevents a stale polyline from being drawn after job completion.
    if (job == null || my == null || job.userLatLng == null) return;

    final active = {
      JobStatus.accepted,
      JobStatus.onTheWay,
      JobStatus.arrived,
      JobStatus.inProgress,
    }.contains(job.status);

    if (!active) return;

    // Capture the job id so we can detect whether the active job changed
    // (e.g. got completed and cleared) while the routing request was in flight.
    final capturedJobId = job.id;
    try {
      final poly = await RoutingService.instance.getRoutePolyline(my, job.userLatLng!);
      // Re-check AFTER the await: if the widget is gone, or the active job
      // was cleared / swapped out during the fetch, drop the result on the
      // floor instead of painting a stale polyline onto a "no active job" map.
      if (!mounted) return;
      if (_activeJob == null || _activeJob!.id != capturedJobId) return;
      setState(() => _route = poly);
    } catch (_) {
      // if routing fails, do not break UI
    }
  }

  Future<void> _callUser(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open dialer on this device.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to launch dialer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to make call. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Job>>(
      stream: FirestoreService.instance.watchMyJobs(),
      builder: (context, snap) {
        // Full-screen loading while waiting for the first Firestore response
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            backgroundColor: kBg,
            body: AppLoader(),
          );
        }

        // Once we have data (or error), extract the active job
        if (snap.hasData) {
          final jobs = snap.data!;
          final active = jobs.where((j) => {
                JobStatus.accepted,
                JobStatus.onTheWay,
                JobStatus.arrived,
                JobStatus.inProgress,
              }.contains(j.status)).toList();

          final newJob = active.isNotEmpty ? active.first : null;

          final changed = (newJob?.id != _activeJob?.id) ||
              (newJob?.status != _activeJob?.status);

          if (changed) {
            _activeJob = newJob;

            // If we just lost the active job (completed / cancelled), clear
            // any stale polyline points synchronously so this same build
            // frame does not pass them into the GoogleMap widget — otherwise
            // the map keeps rendering a route to a job that no longer exists.
            if (newJob == null && _route.isNotEmpty) {
              _route = const [];
            }

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Nothing to route / pan to if the job has been cleared.
              if (_activeJob == null || !mounted) return;
              await _refreshRoute();
              final userLL = _activeJob?.userLatLng;
              if (userLL != null && mounted) {
                await _moveCamera(userLL, zoom: 14);
              }
            });
          }
        }

        return _buildMapStack(context, snap);
      },
    );
  }

  /// Animates the Google Map camera to the given latlong2 point.
  /// Safely waits for the GoogleMapController via the Completer.
  ///
  /// Callers are expected to already have null-checked their own target
  /// coordinates — this method never force-unwraps `_activeJob`.
  Future<void> _moveCamera(ll.LatLng target, {double zoom = 14}) async {
    try {
      final controller = await _mapCompleter.future;
      // Widget may have been disposed while we awaited the controller.
      if (!mounted) return;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(target.latitude, target.longitude),
          zoom,
        ),
      );
    } catch (_) {
      // Swallow camera errors — UI keeps working
    }
  }

  Widget _buildMapStack(BuildContext context, AsyncSnapshot<List<Job>> snap) {
    // Compute initial camera target — NEVER blindly force-unwrap
    // job!.userLatLng!. Priority order:
    //   1. The stranded user's coordinates (when there is an active job).
    //   2. The contractor's own current GPS position (idle / post-completion).
    //   3. Kuala Lumpur city center (cold start before any GPS fix).
    final job = _activeJob;
    final my = _my;
    final LatLng initialTarget;
    if (job != null && job.userLatLng != null) {
      initialTarget = LatLng(job.userLatLng!.latitude, job.userLatLng!.longitude);
    } else if (my != null) {
      initialTarget = LatLng(my.latitude, my.longitude);
    } else {
      initialTarget = const LatLng(3.139, 101.6869); // KL fallback
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 14.0,
          ),
          onMapCreated: (controller) {
            // Store a direct handle for the custom FAB path AND complete
            // the Completer for anything that still awaits it (e.g.
            // `_moveCamera` in the stream listener).
            _mapController = controller;
            if (!_mapCompleter.isCompleted) {
              _mapCompleter.complete(controller);
            }

            // Auto-Locate on load: if there is no active job right now
            // (covers both "never had one" and "just completed one" —
            // the StreamBuilder filter already excludes completed jobs
            // from `_activeJob`), snap the camera to the contractor's
            // own GPS fix so they don't land on the KL fallback.
            if (_activeJob == null) {
              _centerOnCurrentLocation();
            }
          },
          markers: _buildMarkers(job),
          polylines: _buildPolylines(),
          // Auto-Locate UI: show the system blue dot indicator, but HIDE
          // the default Google Maps center-on-me button — we provide our
          // own themed FAB in the bottom-right stack that matches the
          // rest of the dark UI and sits alongside the navigation FAB
          // when there is an active job.
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
        ),

        // --- overlay while location still waiting ---
        if (!_locationReady)
          const Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _TopToast(text: "Getting location..."),
          ),

        // --- JOB UI + FAB stack ---
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── FAB row: "my location" (always) + "navigate" (when
                //    there's an active job with known destination coords).
                //    Rendered ABOVE the bottom panel so it floats on the
                //    right side just above the card per spec.
                Padding(
                  padding: const EdgeInsets.only(right: 24, bottom: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMyLocationFab(),
                      if (job != null && job.userLatLng != null) ...[
                        const SizedBox(width: 12),
                        _buildNavigationFab(job),
                      ],
                    ],
                  ),
                ),
                // ── Bottom panel (premium card / empty state / error).
                _buildBottomPanel(context, snap),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Custom themed "my location" FAB. Uses `Icons.my_location`, sits on the
  /// right side of the map, and taps through to `_centerOnCurrentLocation`.
  /// Always visible — whether or not there is an active job — because the
  /// primary use case is the idle / post-completion screen.
  Widget _buildMyLocationFab() {
    return FloatingActionButton(
      heroTag: 'my_location_fab',
      mini: true,
      backgroundColor: Colors.white,
      elevation: 6,
      tooltip: 'My location',
      onPressed: _centerOnCurrentLocation,
      child: const Icon(Icons.my_location, color: Colors.black87, size: 22),
    );
  }

  /// Launches the platform navigation app toward the stranded user. Only
  /// rendered when there's an active job with known `userLatLng` — guarded
  /// by the caller in `_buildMapStack`.
  Widget _buildNavigationFab(Job job) {
    return FloatingActionButton(
      heroTag: 'nav_fab',
      backgroundColor: Colors.white,
      elevation: 6,
      tooltip: 'Navigate',
      onPressed: () => _launchNavigation(job),
      child: const Icon(Icons.navigation, color: Colors.blue, size: 26),
    );
  }

  /// Builds the map marker set. The stranded user gets the default red pin;
  /// the contractor (if location is known) gets a blue-hued pin as a bonus
  /// on top of the system `myLocation` blue dot.
  ///
  /// When there is NO active job (job == null), we return an empty marker
  /// set — nothing to pin at "the user's location" because there is no user.
  /// This is what the "No active job" idle screen should look like.
  Set<Marker> _buildMarkers(Job? job) {
    // Fast path: no active job → no markers on the map at all. The system
    // `myLocation` blue dot still renders via `myLocationEnabled: true`.
    if (job == null) return const <Marker>{};

    final markers = <Marker>{};

    // Stranded user — default RED pin. Only added if we actually have coords.
    if (job.userLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('stranded_user'),
          position: LatLng(
            job.userLatLng!.latitude,
            job.userLatLng!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: job.userName.isEmpty ? 'Stranded User' : job.userName,
            snippet: job.serviceType,
          ),
        ),
      );
    }

    // Contractor (bonus) — blue hue pin from current state.
    final my = _my;
    if (my != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('contractor_self'),
          position: LatLng(my.latitude, my.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }

    return markers;
  }

  /// Builds the route polyline set (empty when no route has been fetched).
  ///
  /// Defense in depth: even if a stale `_route` list somehow survives a job
  /// transition, we refuse to render a polyline when there is no active job
  /// — this prevents the GoogleMap widget from trying to draw a route to a
  /// destination that no longer exists right after a job is completed.
  Set<Polyline> _buildPolylines() {
    if (_activeJob == null) return const <Polyline>{};
    if (_route.isEmpty) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('route_to_user'),
        points: _route.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        color: Colors.blueAccent,
        width: 5,
      ),
    };
  }

  Future<void> _updateStatus(String jobId, JobStatus newStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await FirestoreService.instance.updateJobStatus(jobId, newStatus);
      await _refreshRoute();
    } catch (e) {
      debugPrint('Failed to update status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _launchNavigation(Job job) async {
    if (job.userLatLng == null) return;
    final lat = job.userLatLng!.latitude;
    final lng = job.userLatLng!.longitude;
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web URL
        final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to launch navigation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Returns ONLY the bottom card widget (premium / empty / error).
  /// The navigation FAB that used to live here has been hoisted into the
  /// FAB row built by `_buildMapStack` alongside the new "my location" FAB.
  Widget _buildBottomPanel(BuildContext context, AsyncSnapshot<List<Job>> snap) {
    if (snap.hasError) return const _BottomPanelError();

    if (_activeJob == null) {
      return const _BottomPanelEmpty(text: 'No active job. Go to Inbox.');
    }

    final job = _activeJob!;

    return _PremiumBottomPanel(
      job: job,
      slideKey: _slideKey,
      isProcessing: _isProcessing,
      onCall: job.userPhone.isEmpty ? null : () => _callUser(job.userPhone),
      onChat: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatPage(jobId: job.id)),
      ),
      onTapDetails: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailsPage(jobId: job.id)),
      ),
      onSlideAction: () async {
        try {
          switch (job.status) {
            case JobStatus.accepted:
              await _updateStatus(job.id, JobStatus.onTheWay);
              break;
            case JobStatus.onTheWay:
              await _updateStatus(job.id, JobStatus.arrived);
              break;
            default:
              break;
          }
        } catch (e) {
          debugPrint('Slide action error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Action failed. Please try again.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
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
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Empty / Error states
// ---------------------------------------------------------------------------

class _BottomPanelEmpty extends StatelessWidget {
  final String text;
  const _BottomPanelEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white38, size: 22),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BottomPanelError extends StatelessWidget {
  const _BottomPanelError();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withAlpha(80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
          SizedBox(width: 12),
          Text(
            'Error loading job data.',
            style: TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium bottom panel
// ---------------------------------------------------------------------------

class _PremiumBottomPanel extends StatefulWidget {
  final Job job;
  final GlobalKey<SlideActionState> slideKey;
  final bool isProcessing;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final VoidCallback onTapDetails;
  final Future<void> Function() onSlideAction;

  const _PremiumBottomPanel({
    required this.job,
    required this.slideKey,
    required this.isProcessing,
    required this.onCall,
    required this.onChat,
    required this.onTapDetails,
    required this.onSlideAction,
  });

  @override
  State<_PremiumBottomPanel> createState() => _PremiumBottomPanelState();
}

class _PremiumBottomPanelState extends State<_PremiumBottomPanel> {
  bool _isCardExpanded = true;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status pill (tappable to collapse/expand) ──
          GestureDetector(
            onTap: () => setState(() => _isCardExpanded = !_isCardExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(30),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Invisible spacer to balance the trailing chevron
                  const SizedBox(width: 22),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_statusIcon, color: _statusColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          job.status.toWire(),
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isCardExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.grey,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // ── Collapsible middle content ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isCardExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Job info rows (tap for details) ──
                        InkWell(
                          onTap: widget.onTapDetails,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _InfoRow(icon: Icons.person, label: job.userName.isEmpty ? 'Unknown' : job.userName),
                                      const SizedBox(height: 8),
                                      _InfoRow(icon: Icons.build, label: job.serviceType),
                                      const SizedBox(height: 8),
                                      _InfoRow(
                                        icon: Icons.location_on,
                                        label: job.userLocation.isEmpty ? 'Location not provided' : job.userLocation,
                                      ),
                                      const SizedBox(height: 8),
                                      _PricePaymentRow(job: job),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right, color: Colors.white38, size: 24),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Call / Message buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.phone,
                                label: 'Call',
                                color: kYellow,
                                onTap: widget.onCall,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StreamBuilder<int>(
                                stream: FirestoreService.instance
                                    .watchUnreadCount(widget.job.id),
                                builder: (context, snap) {
                                  final unread = snap.data ?? 0;
                                  return _ActionButton(
                                    icon: Icons.chat_bubble_outline,
                                    label: 'Message',
                                    color: Colors.white,
                                    onTap: widget.onChat,
                                    badgeCount: unread,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Action area (always visible outside collapsible) ──
          if (job.status == JobStatus.arrived ||
              job.status == JobStatus.accepted ||
              job.status == JobStatus.onTheWay)
            Padding(
              padding: EdgeInsets.fromLTRB(16, _isCardExpanded ? 0 : 14, 16, 16),
              child: job.status == JobStatus.arrived
                  ? SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: widget.onTapDetails,
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: const Text(
                          'Take Proof Photo to Complete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    )
                  : SlideAction(
                      key: widget.slideKey,
                      text: _slideText,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      innerColor: _slideColor,
                      outerColor: const Color(0xFF333333),
                      elevation: 0,
                      sliderButtonIcon: Icon(_slideIcon, color: Colors.black, size: 22),
                      height: 56,
                      borderRadius: 14,
                      enabled: !widget.isProcessing,
                      onSubmit: () {
                        // fire-and-forget: avoids dispose crash on slider animation
                        widget.onSlideAction().catchError((e) {
                          debugPrint('Slide action failed: $e');
                        });
                        return null;
                      },
                    ),
            ),
        ],
      ),
    );
  }

  // ── Slide action config per status ──

  String get _slideText {
    switch (widget.job.status) {
      case JobStatus.accepted:
        return 'Slide to Go On The Way';
      case JobStatus.onTheWay:
        return 'Slide to Confirm Arrival';
      default:
        return 'Slide';
    }
  }

  Color get _slideColor {
    switch (widget.job.status) {
      case JobStatus.accepted:
        return kYellow;
      case JobStatus.onTheWay:
        return Colors.teal;
      default:
        return kYellow;
    }
  }

  IconData get _slideIcon {
    switch (widget.job.status) {
      case JobStatus.accepted:
        return Icons.directions_car;
      case JobStatus.onTheWay:
        return Icons.place;
      default:
        return Icons.arrow_forward;
    }
  }

  Color get _statusColor {
    switch (widget.job.status) {
      case JobStatus.accepted:
        return kYellow;
      case JobStatus.onTheWay:
        return Colors.teal;
      case JobStatus.arrived:
        return Colors.orange;
      case JobStatus.inProgress:
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  IconData get _statusIcon {
    switch (widget.job.status) {
      case JobStatus.accepted:
        return Icons.check_circle;
      case JobStatus.onTheWay:
        return Icons.directions_car;
      case JobStatus.arrived:
        return Icons.place;
      case JobStatus.inProgress:
        return Icons.handyman;
      default:
        return Icons.info_outline;
    }
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final int badgeCount;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricePaymentRow extends StatelessWidget {
  final Job job;
  const _PricePaymentRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final isCash = job.paymentMethod.toLowerCase() == 'cash';
    final badgeLabel = isCash ? 'CASH' : 'FPX / ONLINE';
    final badgeColor = isCash ? Colors.green : Colors.blue;
    final badgeIcon = isCash ? Icons.payments : Icons.account_balance;

    return Row(
      children: [
        const Icon(Icons.attach_money, color: kYellow, size: 18),
        const SizedBox(width: 10),
        Text(
          'RM ${job.totalCost.toStringAsFixed(2)}',
          style: const TextStyle(
            color: kYellow,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withAlpha(30),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withAlpha(100)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                badgeLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}