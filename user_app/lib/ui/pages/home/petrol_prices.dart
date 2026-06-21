import 'package:flutter/material.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/unread_menu_button.dart';

class PetrolPricesPage extends StatelessWidget {
  const PetrolPricesPage({super.key});

  // Current Malaysian retail fuel prices (weekly ceiling price)
  static const _prices = [
    _FuelPrice('RON 95', 'RM 1.99', subsidised: true),
    _FuelPrice('RON 97', 'RM 3.47', subsidised: false),
    _FuelPrice('Diesel', 'RM 3.35', subsidised: false),
  ];

  static const _stations = [
    _Station('Petronas', Icons.local_gas_station, Color(0xFF00A651)),
    _Station('Shell', Icons.local_gas_station, Color(0xFFFFD500)),
    _Station('BHP', Icons.local_gas_station, Color(0xFF0072CE)),
    _Station('Caltex', Icons.local_gas_station, Color(0xFFED1C24)),
    _Station('Petron', Icons.local_gas_station, Color(0xFF0033A0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: const UnreadMenuButton(badgeRing: Color(0xFF1A1A1A)),
        title: const Text(
          'PETROL PRICES',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.local_gas_station, color: Colors.yellow, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'Malaysian Fuel Prices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Weekly ceiling price set by the government',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Fuel price cards
            const Text(
              'CURRENT PRICES',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            ..._prices.map((p) => _FuelPriceCard(price: p)),

            const SizedBox(height: 24),

            // Stations grid
            const Text(
              'FUEL STATIONS',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: _stations.map((s) => _StationCard(station: s)).toList(),
            ),

            const SizedBox(height: 24),

            // Disclaimer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prices are set weekly by the Malaysian government under the Automatic Pricing Mechanism (APM).',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _FuelPrice {
  final String label;
  final String price;
  final bool subsidised;
  const _FuelPrice(this.label, this.price, {this.subsidised = false});
}

class _Station {
  final String name;
  final IconData icon;
  final Color brandColor;
  const _Station(this.name, this.icon, this.brandColor);
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _FuelPriceCard extends StatelessWidget {
  final _FuelPrice price;
  const _FuelPriceCard({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          // Fuel type badge
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                price.label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Price
          Expanded(
            child: Text(
              price.price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Subsidy badge
          if (price.subsidised)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A1B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Subsidised',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Text(
              '/litre',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final _Station station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: station.brandColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(station.icon, color: station.brandColor, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            station.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
