import 'package:flutter/material.dart';

import 'package:user_app/constants/colors.dart';
import 'package:user_app/ui/pages/map/select_car_location.dart';

/// Fuel-delivery configuration screen. Mirrors `battery_options.dart` /
/// `tyre_options.dart` — intervenes between the service grid and
/// `SelectCarLocationPage` so the user can pick fuel type and budget before
/// booking. Total = chosen fuel budget + flat delivery fee.
class FuelOptionsPage extends StatefulWidget {
  final String serviceName;

  const FuelOptionsPage({
    super.key,
    required this.serviceName,
  });

  @override
  State<FuelOptionsPage> createState() => _FuelOptionsPageState();
}

class _FuelOptionsPageState extends State<FuelOptionsPage> {
  /// Flat delivery fee charged on top of the fuel budget. Hard-coded per spec.
  /// If you want this to come from `Services/fuel-delivery.BasePrice` instead,
  /// accept a `basePrice` constructor arg and use it here.
  static const double deliveryFee = 25.0;

  /// Fuel type options. Order matches the SegmentedButton segments below.
  static const List<String> _fuelTypes = ['Ron95', 'Ron97', 'Diesel'];

  /// Upper cap on the fuel budget. Lower bound (RM 5) is shown as a hint in
  /// the field label but isn't strictly enforced — leaving the field empty
  /// is treated as "RM 0" rather than an error so the user isn't blocked
  /// while they're still typing.
  static const double _maxAmount = 100.0;

  String fuelType = 'Ron95';
  double fuelAmount = 10.0;

  /// Inline error shown below the field. Null = no error (Next is enabled
  /// as long as `fuelAmount > 0`).
  String? _amountError;

  late final TextEditingController fuelAmountController;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the default fuelAmount so the field isn't blank on open.
    fuelAmountController = TextEditingController(
      text: fuelAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    fuelAmountController.dispose();
    super.dispose();
  }

  double get totalPrice => fuelAmount + deliveryFee;

  bool get _canProceed => _amountError == null && fuelAmount > 0;

  /// Compact descriptor used as the `serviceRequested` string downstream —
  /// payment confirmation, Firestore Jobs.ServiceType, and the receipt all
  /// render this verbatim.
  String get _serviceLabel =>
      '${widget.serviceName} – $fuelType (RM ${fuelAmount.toStringAsFixed(2)})';

  /// Called on every keystroke. Parses the live text, updates [fuelAmount]
  /// (so [totalPrice] recomputes immediately), and surfaces validation
  /// errors via [_amountError]. Behaviours:
  ///   • empty       → RM 0 (no error; lets user clear and re-type)
  ///   • non-numeric → keep last valid amount, show "enter a valid amount"
  ///   • > RM 100    → keep parsed amount visible (so user sees the cause),
  ///                   show "Maximum is RM 100.00", Next is disabled
  ///   • otherwise   → update amount, clear any previous error
  void _onAmountChanged(String raw) {
    final trimmed = raw.trim();
    setState(() {
      if (trimmed.isEmpty) {
        fuelAmount = 0;
        _amountError = null;
        return;
      }
      final parsed = double.tryParse(trimmed);
      if (parsed == null) {
        _amountError = 'Enter a valid amount.';
        return;
      }
      fuelAmount = parsed;
      _amountError = parsed > _maxAmount
          ? 'Maximum is RM ${_maxAmount.toStringAsFixed(2)}.'
          : null;
    });
  }

  void _onNext() {
    if (!_canProceed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectCarLocationPage(
          serviceRequested: _serviceLabel,
          totalAmount: totalPrice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Image.asset(
          'lib/images/Logo_2.png',
          height: 100,
          fit: BoxFit.contain,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            const Center(
              child: Icon(
                Icons.local_gas_station,
                size: 48,
                color: Colors.yellow,
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'CONFIGURE YOUR ORDER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Service: ${widget.serviceName}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 28),

            // ── Fuel type ──
            const Text(
              'FUEL TYPE',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            _FuelTypePicker(
              options: _fuelTypes,
              selected: fuelType,
              onChanged: (v) => setState(() => fuelType = v),
            ),
            const SizedBox(height: 24),

            // ── Fuel amount ──
            const Text(
              'How much fuel do you need?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: fuelAmountController,
              onChanged: _onAmountChanged,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              cursorColor: Colors.yellow,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Enter Fuel Amount (RM 5 - RM 100)',
                labelStyle: const TextStyle(color: Colors.white60),
                floatingLabelStyle: const TextStyle(color: Colors.yellow),
                prefixText: 'RM ',
                prefixStyle: const TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                errorText: _amountError,
                errorStyle: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.yellow.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.yellow,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF6B6B),
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF6B6B),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom summary bar ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breakdown + total
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fuel (RM ${fuelAmount.toStringAsFixed(2)}) + '
                        'Delivery (RM ${deliveryFee.toStringAsFixed(2)})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'RM ${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: kYellow.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _canProceed ? _onNext : null,
                child: const Text(
                  'NEXT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SegmentedButton-style picker themed in IRAMS yellow on dark cards.
/// Falls back from Material 3 SegmentedButton's default look so it matches
/// the rest of the app rather than the M3 surface palette.
class _FuelTypePicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _FuelTypePicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final o in options)
          ButtonSegment<String>(
            value: o,
            label: Text(o),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.yellow
              : const Color(0xFF1E1E1E);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.black
              : Colors.white70;
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }
}
