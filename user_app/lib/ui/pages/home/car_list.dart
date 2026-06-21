import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/unread_menu_button.dart';
import 'package:user_app/services/user_firestore_service.dart';
import 'package:user_app/ui/pages/home/add_car.dart';

class CarListPage extends StatefulWidget {
  const CarListPage({super.key});

  @override
  State<CarListPage> createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  String? _customUserId;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
    _loadCustomId();
  }

  Future<void> _loadCustomId() async {
    final id = await UserFirestoreService.instance.getCustomUserId();
    if (mounted) {
      setState(() {
        _customUserId = id;
        _loadingId = false;
      });
    }
  }

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
          'MY VEHICLES',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _loadingId
          ? const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            )
          : (_customUserId == null || _customUserId!.isEmpty)
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No linked profile found.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: UserFirestoreService.instance
                  .watchMyVehicles(_customUserId!),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.yellow),
                  );
                }

                final docs = (snap.data?.docs ?? [])
                    .where((d) => !UserFirestoreService.isVehicleDeleted(d.data()))
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car_outlined,
                            color: Colors.grey, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No vehicles yet.\nTap the button below to add one.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    return _VehicleCard(
                      vehicleId: doc.id,
                      make: (data['Make'] ?? '').toString(),
                      model: (data['Model'] ?? '').toString(),
                      year: (data['Year'] ?? '').toString(),
                      plate: (data['NumberPlate'] ?? '').toString(),
                    );
                  },
                );
              },
            ),

      // Floating add button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD CAR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RideDetailsPage()),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle card with edit / delete
// ---------------------------------------------------------------------------

class _VehicleCard extends StatelessWidget {
  final String vehicleId;
  final String make;
  final String model;
  final String year;
  final String plate;

  const _VehicleCard({
    required this.vehicleId,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          // Car icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car, color: Colors.yellow, size: 24),
          ),

          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$make $model${year.isNotEmpty ? ' ($year)' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.yellow, size: 20),
            tooltip: 'Edit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideDetailsPage(
                    vehicleId: vehicleId,
                    initialBrand: make,
                    initialModel: model,
                    initialYear: year,
                    initialPlate: plate,
                  ),
                ),
              );
            },
          ),

          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Vehicle',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove $plate ($make $model) from your vehicles?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserFirestoreService.instance.deleteVehicle(vehicleId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vehicle deleted'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child:
                const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
