import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:user_app/ui/pages/payment/payment_confirmation.dart';

class BatteryMatchedPage extends StatefulWidget {
  final LatLng carLocation;

  const BatteryMatchedPage({super.key, required this.carLocation});

  @override
  State<BatteryMatchedPage> createState() => _BatteryMatchedPageState();
}

class BatteryOption {
  final String id;
  final String name;
  final double price;
  final String warranty;

  BatteryOption({
    required this.id,
    required this.name,
    required this.price,
    required this.warranty,
  });
}

enum BatteryServiceType {
  newBattery,
  jumpstart,
}

class _BatteryMatchedPageState extends State<BatteryMatchedPage> {
  BatteryOption? _selectedBattery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
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

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "WE'VE MATCHED IT!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Car location:\nLat: ${widget.carLocation.latitude}, '
              'Lng: ${widget.carLocation.longitude}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 20),

            _batteryTile(
              option: BatteryOption(
                id: 'mutlu',
                name: 'MUTLU',
                price: 209.00,
                warranty: '3 months',
              ),
            ),

            const SizedBox(height: 14),

            _batteryTile(
              option: BatteryOption(
                id: 'century',
                name: 'CENTURY ROADMASTER',
                price: 225.00,
                warranty: '15 months',
              ),
            ),

            const SizedBox(height: 14),

            _batteryTile(
              option: BatteryOption(
                id: 'camel',
                name: 'CAMEL PLUS',
                price: 249.00,
                warranty: '18 months',
              ),
            ),
          ],
        ),
      ),

      // CONFIRM BUTTON BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedBattery == null
                  ? Colors.yellow.withValues(alpha:0.25)
                  : Colors.yellow,
              foregroundColor: Colors.black,
              elevation: _selectedBattery == null ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (_selectedBattery == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentConfirmationPage(
                    serviceRequested: 'Battery – New Battery',
                    batteryName: _selectedBattery!.name,
                    warranty: _selectedBattery!.warranty,
                    totalAmount: _selectedBattery!.price,
                  ),
                ),
              );
            },
            child: Text(
              'CONFIRM',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _selectedBattery == null
                    ? Colors.black.withValues(alpha:0.5)
                    : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Battery selection card
  Widget _batteryTile({required BatteryOption option}) {
    final selected = _selectedBattery?.id == option.id;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _selectedBattery = option);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.yellow : const Color(0xFF2A2A2A),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha:0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${option.price.toStringAsFixed(2)} · Warranty ${option.warranty}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: Colors.yellow),
          ],
        ),
      ),
    );
  }
}
