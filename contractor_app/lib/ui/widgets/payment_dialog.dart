import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/job.dart';

// ── Result type ────────────────────────────────────────────────────────────────

/// Returned by [FinalizeJobDialog] when the contractor confirms.
class FinalizeJobResult {
  final double totalCost;
  final String paymentMethod; // 'Cash' or 'Online'
  const FinalizeJobResult({required this.totalCost, required this.paymentMethod});
}

// ── FinalizeJobDialog ──────────────────────────────────────────────────────────

/// Grab-style confirmation dialog shown when the contractor taps "Complete Job".
/// The total amount is the massive, dominant central element. Commission
/// breakdown sits in a subtle secondary card below. Returns [FinalizeJobResult]
/// or null if cancelled.
class FinalizeJobDialog extends StatelessWidget {
  final Job job;
  const FinalizeJobDialog({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final double price = job.totalCost.toDouble();
    final double commission = price * 0.15;
    final double earnings = price - commission;
    final bool isCash = job.paymentMethod.toLowerCase() == 'cash';

    return Dialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Context label ──
            Text(
              isCash
                  ? 'Please collect cash from customer'
                  : 'Online Payment Verified',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isCash ? Colors.white54 : Colors.green,
                fontSize: 14,
                fontWeight: isCash ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // ── MASSIVE amount ──
            Text(
              'RM ${isCash ? price.toStringAsFixed(2) : earnings.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            if (!isCash) ...[
              const SizedBox(height: 6),
              const Text(
                'Earnings to be credited to Wallet',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),

            // ── Breakdown card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [
                  _BreakdownRow(
                    label: 'Total Fare',
                    value: 'RM ${price.toStringAsFixed(2)}',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Colors.white12),
                  ),
                  _BreakdownRow(
                    label: 'System Commission (15%)',
                    value: '- RM ${commission.toStringAsFixed(2)}',
                    valueColor: Colors.redAccent,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Colors.white12),
                  ),
                  _BreakdownRow(
                    label: 'Your Earnings',
                    value: 'RM ${earnings.toStringAsFixed(2)}',
                    valueColor: Colors.green,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Primary action button (full width) ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  FinalizeJobResult(
                    totalCost: price,
                    paymentMethod: isCash ? 'Cash' : 'Online',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCash ? Colors.green : kYellow,
                  foregroundColor: isCash ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isCash ? 'Confirm Cash Collected' : 'Complete Job',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Cancel (text button, not competing visually) ──
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white70,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: bold ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
