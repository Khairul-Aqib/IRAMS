import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:user_app/ui/pages/payment/fpx_payment_page.dart';

class PaymentConfirmationPage extends StatelessWidget {
  final String serviceRequested;
  final String batteryName;
  final String warranty;
  final double totalAmount;
  final String? jobId;
  final String? userLocation;
  final String? contractorId;
  final GeoPoint? userGeo;
  final String? towingDestinationName;
  final GeoPoint? towingDestinationGeo;
  final String? distanceKm;

  const PaymentConfirmationPage({
    super.key,
    required this.serviceRequested,
    this.batteryName = 'N/A',
    this.warranty = 'N/A',
    required this.totalAmount,
    this.jobId,
    this.userLocation,
    this.contractorId,
    this.userGeo,
    this.towingDestinationName,
    this.towingDestinationGeo,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    // Split "Battery Replacement – NS40ZL" into service name + battery model.
    final parts = serviceRequested.split(' – ');
    final displayService = parts.first.trim();
    final displayBattery =
        parts.length > 1 ? parts.sublist(1).join(' – ').trim() : batteryName;

    final bool isBatteryService =
        serviceRequested.toLowerCase().contains('battery');

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHECK AND CONFIRM!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _infoRow('SERVICE REQUESTED', displayService),

            if (isBatteryService) ...[
              _infoRow('BATTERY', displayBattery),
              if (warranty != 'N/A') _infoRow('WARRANTY', warranty),
            ],

            if (userLocation != null && userLocation!.isNotEmpty)
              _infoRow('PICKUP LOCATION', userLocation!),

            if (towingDestinationName != null &&
                towingDestinationName!.isNotEmpty)
              _infoRow('TOWING DESTINATION', towingDestinationName!),

            if (distanceKm != null)
              _infoRow('DISTANCE', '$distanceKm km'),

            const SizedBox(height: 20),

            const Divider(color: Color(0xFF2A2A2A)),

            const SizedBox(height: 20),

            const Text(
              'ESTIMATED COST',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 6),

            Text(
              'RM ${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FpxPaymentPage(
                        jobId: jobId ?? 'JOB-${DateTime.now().millisecondsSinceEpoch}',
                        serviceType: displayService,
                        totalAmount: totalAmount,
                        userLocation: userLocation ?? '',
                        buyerEmail: user?.email ?? '',
                        buyerName: user?.displayName ?? user?.email ?? 'User',
                        contractorId: contractorId,
                        batteryModel: isBatteryService ? displayBattery : null,
                        warranty: isBatteryService ? warranty : null,
                        userGeo: userGeo,
                        towingDestinationName: towingDestinationName,
                        towingDestinationGeo: towingDestinationGeo,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'PROCEED TO PAYMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
