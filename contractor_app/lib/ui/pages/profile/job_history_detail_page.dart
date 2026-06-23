import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';

/// Read-only receipt page for a completed job, inspired by Grab's layout.
///
/// Accepts all data via constructor so no extra Firestore reads are needed.
class JobHistoryDetailPage extends StatelessWidget {
  final String jobId;
  final String serviceType;
  final num totalCost;
  final num commission;
  final num earning;
  final String paymentMethod;
  final DateTime? completedAt;

  const JobHistoryDetailPage({
    super.key,
    required this.jobId,
    required this.serviceType,
    required this.totalCost,
    required this.commission,
    required this.earning,
    required this.paymentMethod,
    this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = completedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(completedAt!.toLocal())
        : 'Date not available';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Job Receipt'),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Hero: Net Earnings ──────────────────────────────────────
          _buildEarningsHero(),

          const SizedBox(height: 24),

          // ── Job Information Card ────────────────────────────────────
          _buildSectionCard(
            title: 'Job Information',
            children: [
              _infoRow('Job ID', jobId, context),
              const Divider(color: kBorder, height: 24),
              _infoRow('Service', serviceType, null),
              const Divider(color: kBorder, height: 24),
              _infoRow('Date & Time', dateStr, null),
              const Divider(color: kBorder, height: 24),
              _infoRow(
                'Payment Method',
                paymentMethod.toLowerCase() == 'cash' ? 'Cash' : 'FPX / Online',
                null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Earnings Breakdown Card ─────────────────────────────────
          _buildSectionCard(
            title: 'Earnings Details',
            children: [
              _earningsRow('Total Fare', totalCost, isBold: false),
              const SizedBox(height: 12),
              _earningsRow(
                'Platform Commission (15%)',
                -commission,
                isBold: false,
                valueColor: Colors.redAccent.shade100,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: kBorder, height: 1),
              ),
              _earningsRow('Net Earnings', earning, isBold: true, valueColor: kYellow),
            ],
          ),

          const SizedBox(height: 32),

          // ── Footer note ─────────────────────────────────────────────
          Center(
            child: Text(
              'Thank you for using IRAMS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Section ──────────────────────────────────────────────────────

  Widget _buildEarningsHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kYellow.withOpacity(0.18),
            kYellow.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kYellow.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            'Your Net Earnings',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RM ${earning.toStringAsFixed(2)}',
            style: const TextStyle(
              color: kYellow,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              serviceType,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card ──────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Info Row (label / value) ──────────────────────────────────────────

  Widget _infoRow(String label, String value, BuildContext? context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: context != null && label == 'Job ID'
              ? GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Job ID copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ],
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  // ── Earnings Row ──────────────────────────────────────────────────────

  Widget _earningsRow(
    String label,
    num amount, {
    bool isBold = false,
    Color? valueColor,
  }) {
    final isNegative = amount < 0;
    final prefix = isNegative ? '-' : '';
    final display = 'RM ${amount.abs().toStringAsFixed(2)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$prefix$display',
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
