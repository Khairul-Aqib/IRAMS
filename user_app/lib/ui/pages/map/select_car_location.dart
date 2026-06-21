import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:user_app/ui/pages/map/location_picker_page.dart';
import 'package:user_app/ui/pages/map/towing_destination_picker.dart';
import 'package:user_app/ui/pages/payment/payment_confirmation.dart';

class SelectCarLocationPage extends StatefulWidget {
  final String serviceRequested;
  final double totalAmount;

  const SelectCarLocationPage({
    super.key,
    required this.serviceRequested,
    required this.totalAmount,
  });

  @override
  State<SelectCarLocationPage> createState() => _SelectCarLocationPageState();
}

class _SelectCarLocationPageState extends State<SelectCarLocationPage> {
  PickedLocation? _breakdownLocation;

  // Towing-only state
  PickedLocation? _towingDestination;
  double _distanceKm = 0;
  double _totalCost = 0;

  static const double _ratePerKm = 5.0;

  bool get _isTowing =>
      widget.serviceRequested.toLowerCase().contains('towing');

  @override
  void initState() {
    super.initState();
    _totalCost = widget.totalAmount;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBreakdownPicker());
  }

  // ── Breakdown picker ───────────────────────────────────────────────────

  Future<void> _openBreakdownPicker() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _breakdownLocation = result;
        // Reset destination when breakdown changes (towing only)
        if (_isTowing) {
          _towingDestination = null;
          _distanceKm = 0;
          _totalCost = widget.totalAmount;
        }
      });
    }
  }

  // ── Destination picker (towing) ────────────────────────────────────────

  Future<void> _openDestinationPicker() async {
    if (_breakdownLocation == null) return;

    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => TowingDestinationPickerPage(
          breakdownLocation: _breakdownLocation!.latLng,
          basePrice: widget.totalAmount,
          serviceType: widget.serviceRequested,
          breakdownAddress: _breakdownLocation!.addressName,
          breakdownGeo: _breakdownLocation!.geoPoint,
        ),
      ),
    );

    if (result != null && mounted) {
      final meters = Geolocator.distanceBetween(
        _breakdownLocation!.latLng.latitude,
        _breakdownLocation!.latLng.longitude,
        result.latLng.latitude,
        result.latLng.longitude,
      );
      final km = meters / 1000.0;

      setState(() {
        _towingDestination = result;
        _distanceKm = km;
        _totalCost = widget.totalAmount + (km * _ratePerKm);
      });
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  bool get _canProceed {
    if (_breakdownLocation == null) return false;
    if (_isTowing && _towingDestination == null) return false;
    return true;
  }

  void _onNextPressed() {
    if (!_canProceed) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationPage(
          serviceRequested: widget.serviceRequested,
          totalAmount: _isTowing ? _totalCost : widget.totalAmount,
          userLocation: _breakdownLocation!.addressName,
          userGeo: _breakdownLocation!.geoPoint,
          towingDestinationName:
              _isTowing ? _towingDestination!.addressName : null,
          towingDestinationGeo:
              _isTowing ? _towingDestination!.geoPoint : null,
          distanceKm:
              _isTowing ? _distanceKm.toStringAsFixed(1) : null,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "WHERE'S YOUR CAR?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: Breakdown Location ──
            const Text(
              'Breakdown Location',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the card below to pick your car\'s exact location on the map.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),

            _locationCard(
              picked: _breakdownLocation,
              placeholder: 'Tap to select location',
              icon: _breakdownLocation != null
                  ? Icons.check_circle
                  : Icons.add_location_alt,
              onTap: _openBreakdownPicker,
            ),

            // ── Section 2: Towing Destination (conditional) ──
            if (_isTowing) ...[
              const SizedBox(height: 28),
              const Text(
                'Towing Destination',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _breakdownLocation == null
                    ? 'Select your breakdown location first.'
                    : 'Tap below to pick where your car should be towed.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),

              _locationCard(
                picked: _towingDestination,
                placeholder: 'Tap to select destination',
                icon: _towingDestination != null
                    ? Icons.check_circle
                    : Icons.local_shipping,
                iconColor: _breakdownLocation == null
                    ? Colors.grey
                    : Colors.yellow,
                borderColor: _towingDestination != null
                    ? Colors.yellow
                    : _breakdownLocation == null
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFF2A2A2A),
                onTap: _breakdownLocation == null
                    ? null
                    : _openDestinationPicker,
              ),

              // Distance info
              if (_towingDestination != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Distance: ${_distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],

            const Spacer(),

            // ── Estimated cost ──
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.serviceRequested,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'RM ${(_isTowing ? _totalCost : widget.totalAmount).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: !_canProceed
                  ? Colors.yellow.withValues(alpha: 0.25)
                  : Colors.yellow,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.black,
              disabledBackgroundColor: Colors.yellow.withValues(alpha: 0.25),
              elevation: !_canProceed ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _canProceed ? _onNextPressed : null,
            child: const Text(
              'NEXT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable location card ─────────────────────────────────────────────

  Widget _locationCard({
    required PickedLocation? picked,
    required String placeholder,
    required IconData icon,
    Color iconColor = Colors.yellow,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    final effectiveBorder = borderColor ??
        (picked != null ? Colors.yellow : const Color(0xFF2A2A2A));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: effectiveBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                picked?.addressName ?? placeholder,
                style: TextStyle(
                  color: picked != null ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
