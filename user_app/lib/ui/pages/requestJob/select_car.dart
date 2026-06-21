import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:user_app/services/user_firestore_service.dart';
import 'package:user_app/ui/pages/requestJob/select_assistance.dart';
import 'package:user_app/ui/pages/home/add_car.dart';

class SelectCarPage extends StatefulWidget {
  const SelectCarPage({super.key});

  @override
  State<SelectCarPage> createState() => _SelectCarPageState();
}

class _SelectCarPageState extends State<SelectCarPage> {
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(
          'lib/images/Logo_2.png',
          height: 100,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT YOUR CAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Which car needs our attention? Add a new car if it's not on this list!",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ── Vehicle list from Firestore ──
            Expanded(
              child: _loadingId
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.yellow),
                    )
                  : (_customUserId == null || _customUserId!.isEmpty)
                      ? const Center(
                          child: Text(
                            'No linked profile found.',
                            style: TextStyle(color: Colors.white54),
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
                            child:
                                CircularProgressIndicator(color: Colors.yellow),
                          );
                        }

                        final docs = snap.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No vehicles yet.\nTap "ADD NEW CAR" below.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final doc = docs[i];
                            final data = doc.data();
                            return _VehicleTile(
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RideDetailsPage()),
              );
            },
            child: const Text(
              'ADD NEW CAR',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single vehicle tile with Edit / Delete actions
// ---------------------------------------------------------------------------

class _VehicleTile extends StatelessWidget {
  final String vehicleId;
  final String make;
  final String model;
  final String year;
  final String plate;

  const _VehicleTile({
    required this.vehicleId,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // ── Tap to select this car for service ──
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelectAssistancePage(),
                  ),
                );
              },
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
          ),

          // ── Edit button ──
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

          // ── Delete button ──
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
        title: const Text('Delete Vehicle', style: TextStyle(color: Colors.white)),
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
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
