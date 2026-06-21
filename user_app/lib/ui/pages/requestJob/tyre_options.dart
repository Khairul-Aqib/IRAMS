import 'package:flutter/material.dart';
import 'package:user_app/ui/pages/map/select_car_location.dart';
import 'package:user_app/ui/pages/map/car_tow_map.dart';

class TyreOptionsPage extends StatelessWidget {
  const TyreOptionsPage({super.key});

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

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.tire_repair, size: 48, color: Colors.yellow),

            const SizedBox(height: 16),

            const Text(
              'TYRES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'We can replace your spare tyre or tow your car safely.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),

            const SizedBox(height: 30),

            /// 🔧 SPARE TYRE CHANGE → PAYMENT FLOW
            _optionButton(
              title: 'SPARE TYRE CHANGE',
              subtitle: 'Have a spare tyre (RM 60)',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelectCarLocationPage(
                      serviceRequested: 'Tyres – Spare Tyre Replacement',
                      totalAmount: 60.00,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            /// 🚗 TOWING → TOW MAP FLOW
            _optionButton(
              title: 'I WANT TO TOW IT',
              subtitle: 'No spare tyre available',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CarTowMapPage(
                      serviceRequested: 'Tyres – Towing',
                      totalAmount: 160.00,
                    ),
                  ),
                );
              },
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (states) {
                      if (states.contains(WidgetState.pressed)) {
                        return const Color(0xFFE6E600); // darker yellow
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFFE6E600);
                      }
                      return Colors.yellow; // #FFFF00
                    },
                  ),
                  foregroundColor: WidgetStateProperty.all(Colors.black),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CHAT WITH US',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _optionButton({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
