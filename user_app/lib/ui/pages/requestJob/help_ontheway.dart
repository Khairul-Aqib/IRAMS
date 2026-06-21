import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:user_app/services/gps_utils.dart';
import 'package:user_app/ui/pages/map/active_job_tracking.dart';

/// Shows contractor info and live ETA while help is en route.
///
/// Reads the contractor's `LastLocation` from Firestore every 10 seconds
/// and recalculates the distance-based ETA to the user's car location.
class HelpOnTheWayPage extends StatefulWidget {
  final String? jobId;
  final LatLng? userCarLocation;

  const HelpOnTheWayPage({
    super.key,
    this.jobId,
    this.userCarLocation,
  });

  @override
  State<HelpOnTheWayPage> createState() => _HelpOnTheWayPageState();
}

class _HelpOnTheWayPageState extends State<HelpOnTheWayPage> {
  Timer? _etaTimer;
  double _etaSeconds = 0;
  double _distanceMeters = 0;
  String _contractorName = '';
  String _contractorPhone = '';
  String _vehicleInfo = '';

  @override
  void initState() {
    super.initState();
    _loadJobInfo();
    _startEtaPolling();
  }

  /// Load initial job + contractor info from Firestore.
  Future<void> _loadJobInfo() async {
    if (widget.jobId == null) return;

    try {
      final jobSnap = await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(widget.jobId)
          .get();

      if (!jobSnap.exists) return;
      final data = jobSnap.data()!;

      // Resolve contractor reference
      final contractorRef = data['ContractorAssigned'];
      if (contractorRef is DocumentReference) {
        final cSnap = await contractorRef.get();
        if (cSnap.exists) {
          final cData = cSnap.data() as Map<String, dynamic>? ?? {};
          if (mounted) {
            setState(() {
              _contractorName = (cData['FullName'] ?? 'Contractor').toString();
              _contractorPhone = (cData['PhoneNumber'] ?? '').toString();
              _vehicleInfo = (cData['CompanyName'] ?? '').toString();
            });
          }

          // Calculate initial ETA
          _calculateEtaFromContractor(cData);
        }
      }
    } catch (_) {}
  }

  /// Poll contractor location every 10 seconds for live ETA.
  void _startEtaPolling() {
    _etaTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (widget.jobId == null) return;

      try {
        final jobSnap = await FirebaseFirestore.instance
            .collection('Jobs')
            .doc(widget.jobId)
            .get();

        if (!jobSnap.exists) return;
        final data = jobSnap.data()!;

        final contractorRef = data['ContractorAssigned'];
        if (contractorRef is DocumentReference) {
          final cSnap = await contractorRef.get();
          if (cSnap.exists) {
            _calculateEtaFromContractor(
                cSnap.data() as Map<String, dynamic>? ?? {});
          }
        }
      } catch (_) {}
    });
  }

  void _calculateEtaFromContractor(Map<String, dynamic> cData) {
    final userLoc = widget.userCarLocation;
    if (userLoc == null) return;

    final geo = cData['LastLocation'];
    if (geo is! GeoPoint) return;

    final contractorLoc = LatLng(geo.latitude, geo.longitude);

    final dist = haversineDistance(contractorLoc, userLoc);
    final eta = estimateEtaSeconds(contractorLoc, userLoc);

    if (mounted) {
      setState(() {
        _distanceMeters = dist;
        _etaSeconds = eta;
      });
    }
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etaText = _etaSeconds > 0 ? formatEta(_etaSeconds) : '--';
    final distText = _distanceMeters >= 1000
        ? '${(_distanceMeters / 1000).toStringAsFixed(1)} km away'
        : _distanceMeters > 0
            ? '${_distanceMeters.round()} m away'
            : '';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help is on the way!',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow),
              ),
              child: const Text(
                'Your service provider is heading to your location.',
                style: TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // DRIVER CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _contractorName.isNotEmpty ? _contractorName : 'Finding contractor...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_vehicleInfo.isNotEmpty)
                          Text(
                            _vehicleInfo,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        if (distText.isNotEmpty)
                          Text(
                            distText,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ETA
            const Text('Arriving in', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 6),
            Text(
              etaText,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.yellow,
              ),
            ),

            const SizedBox(height: 24),

            // CALL DRIVER
            if (_contractorPhone.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone, color: Colors.yellow),
                title: Text(
                  _contractorPhone,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Contact Number',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () => _callDriver(_contractorPhone),
              ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveJobTrackingPage(
                        jobId: widget.jobId ?? '',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.location_on),
                label: const Text(
                  'Track My Driver',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
