import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/payment.dart';
import '../../../services/invoice_service.dart';
import '../home/homepage.dart';

/// Digital receipt displayed after a successful FPX payment.
///
/// Shows: receipt number, FPX transaction ID, service details,
/// amount breakdown (subtotal, platform fee, total), timestamp.
class DigitalReceiptPage extends StatelessWidget {
  final String invoiceId;
  final FpxTransaction fpxTxn;
  final String serviceType;
  final double totalAmount;

  const DigitalReceiptPage({
    super.key,
    required this.invoiceId,
    required this.fpxTxn,
    required this.serviceType,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final platformFee = (totalAmount * InvoiceService.platformFeeRate).roundToDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Payment Receipt', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Success indicator ──
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 12),
            const Text(
              'PAYMENT SUCCESSFUL',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // ── Receipt card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Center(
                    child: Text(
                      'IRAMS',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Roadside Assistance',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 12),

                  // Receipt details
                  _receiptRow('Receipt No',
                      'IRAMS-${(invoiceId.length >= 8 ? invoiceId.substring(0, 8) : invoiceId).toUpperCase()}'),
                  _receiptRow('FPX Txn ID', fpxTxn.fpxTxnId),
                  _receiptRow('Date', dateFmt.format(fpxTxn.transactionTime)),
                  _receiptRow('Payment Method', 'FPX Online Banking'),
                  _receiptRow('Bank', _bankName(fpxTxn.buyerBankId)),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 12),

                  // Service details
                  _receiptRow('Service', serviceType),
                  _receiptRow('Status', 'Paid'),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 12),

                  // Amount breakdown
                  _receiptRow('Subtotal', 'RM ${(totalAmount - platformFee).toStringAsFixed(2)}'),
                  _receiptRow('Platform Fee (${(InvoiceService.platformFeeRate * 100).toInt()}%)',
                      'RM ${platformFee.toStringAsFixed(2)}'),

                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF555555), thickness: 1.5),
                  const SizedBox(height: 8),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL PAID',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'RM ${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 8),

                  // Auth code
                  Center(
                    child: Text(
                      'Auth Code: ${fpxTxn.debitAuthCode}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Action buttons ──
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
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (_) => false,
                  );
                },
                child: const Text(
                  'BACK TO HOME',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _bankName(String bankId) {
    const map = {
      'ABB0233': 'Affin Bank',
      'ABMB0212': 'Alliance Bank',
      'AMBB0209': 'AmBank',
      'BIMB0340': 'Bank Islam',
      'BMMB0341': 'Bank Muamalat',
      'BKRM0602': 'Bank Rakyat',
      'BSN0601': 'BSN',
      'BCBB0235': 'CIMB Bank',
      'HLB0224': 'Hong Leong Bank',
      'HSBC0223': 'HSBC Bank',
      'KFH0346': 'Kuwait Finance House',
      'MB2U0227': 'Maybank',
      'MBB0228': 'Maybank (Maybank2E)',
      'OCBC0229': 'OCBC Bank',
      'PBB0233': 'Public Bank',
      'RHB0218': 'RHB Bank',
      'SCB0216': 'Standard Chartered',
      'UOB0226': 'UOB Bank',
    };
    return map[bankId] ?? bankId;
  }
}
