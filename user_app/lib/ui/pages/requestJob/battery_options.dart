import 'package:flutter/material.dart';
import 'package:user_app/constants/colors.dart';
import 'package:user_app/ui/pages/map/select_car_location.dart';
import 'package:user_app/ui/pages/messages/support_chat_page.dart';

class _BatteryModel {
  final String id;
  final String name;
  final double price;

  const _BatteryModel({
    required this.id,
    required this.name,
    required this.price,
  });
}

const _batteryModels = [
  _BatteryModel(id: 'ns40zl', name: 'NS40ZL', price: 185),
  _BatteryModel(id: 'ns60l', name: 'NS60L', price: 220),
  _BatteryModel(id: 'din65l', name: 'DIN65L', price: 350),
];

class BatteryOptionsPage extends StatefulWidget {
  final String serviceName;
  final double basePrice;

  const BatteryOptionsPage({
    super.key,
    required this.serviceName,
    required this.basePrice,
  });

  @override
  State<BatteryOptionsPage> createState() => _BatteryOptionsPageState();
}

class _BatteryOptionsPageState extends State<BatteryOptionsPage> {
  String? _selectedId;

  _BatteryModel? get _selectedModel =>
      _selectedId == null
          ? null
          : _batteryModels.firstWhere((m) => m.id == _selectedId);

  double get _totalPrice =>
      widget.basePrice + (_selectedModel?.price ?? 0);

  @override
  Widget build(BuildContext context) {
    final selected = _selectedModel;

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
            const Icon(
              Icons.battery_charging_full,
              size: 48,
              color: Colors.yellow,
            ),

            const SizedBox(height: 16),

            const Text(
              'SELECT BATTERY MODEL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Service: ${widget.serviceName}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),

            const SizedBox(height: 24),

            for (final model in _batteryModels) ...[
              _batteryTile(model),
              const SizedBox(height: 14),
            ],

            const Spacer(),

            // Total price display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Price',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'RM ${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Not sure?',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kYellow),
                  foregroundColor: kYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportChatPage(),
                    ),
                  );
                },
                child: const Text(
                  'CHAT WITH US',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
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
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: selected == null
                  ? Colors.yellow.withValues(alpha: 0.25)
                  : Colors.yellow,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.black,
              disabledBackgroundColor: Colors.yellow.withValues(alpha: 0.25),
              elevation: selected == null ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: selected == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelectCarLocationPage(
                          serviceRequested:
                              '${widget.serviceName} – ${selected.name}',
                          totalAmount: _totalPrice,
                        ),
                      ),
                    );
                  },
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _batteryTile(_BatteryModel model) {
    final isSelected = _selectedId == model.id;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedId = model.id),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.yellow : const Color(0xFF2A2A2A),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha: 0.25),
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
                    model.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${model.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.yellow),
          ],
        ),
      ),
    );
  }
}
