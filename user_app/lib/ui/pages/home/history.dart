import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:user_app/services/invoice_service.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/unread_menu_button.dart';
import 'package:user_app/ui/pages/map/active_job_tracking.dart';
import 'package:user_app/ui/pages/payment/receipt_viewer_page.dart';

// ---------------------------------------------------------------------------
// Unified history item model
// ---------------------------------------------------------------------------

enum _HistorySource { job, invoice }

class _HistoryItem {
  final String docId;
  final _HistorySource source;
  final String serviceType;
  final String userLocation;
  final double totalCost;
  final String status;
  final DateTime? date;
  final Map<String, dynamic> raw;

  _HistoryItem({
    required this.docId,
    required this.source,
    required this.serviceType,
    required this.userLocation,
    required this.totalCost,
    required this.status,
    required this.date,
    required this.raw,
  });

  String get displayStatus {
    if (isCancelled) return 'Cancelled';
    if (isCompleted) return 'Completed';
    return 'Ongoing';
  }

  /// True for invoice rows AND for job rows whose Status is 'Completed' but
  /// have no matching invoice (cash flow, manual admin completions, etc.).
  bool get isCompleted =>
      source == _HistorySource.invoice ||
      (source == _HistorySource.job &&
          status.toLowerCase() == 'completed');

  bool get isOngoing =>
      source == _HistorySource.job && !isCancelled && !isCompleted;

  bool get isCancelled =>
      source == _HistorySource.job &&
      status.toLowerCase() == 'cancelled';
  DateTime? get dateCancelled {
    final raw = this.raw['DateCancelled'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

// ---------------------------------------------------------------------------
// History page
// ---------------------------------------------------------------------------

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: const UnreadMenuButton(badgeRing: Color(0xFF1A1A1A)),
        title: const Text(
          'HISTORY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: authUid == null
          ? const Center(
              child: Text(
                'Please sign in to view your history',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          : const _HistoryBody(),
    );
  }
}

// ---------------------------------------------------------------------------
// Body: two StreamBuilders combined
// ---------------------------------------------------------------------------

class _HistoryBody extends StatefulWidget {
  const _HistoryBody();

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  String? _resolvedId;
  bool _loading = true;
  bool _profileMissing = false;

  @override
  void initState() {
    super.initState();
    _resolveCustomId();
  }

  Future<void> _resolveCustomId() async {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (authUid.isEmpty) {
      if (mounted) setState(() { _loading = false; _profileMissing = true; });
      return;
    }

    final qs = await FirebaseFirestore.instance
        .collection('Users')
        .where('authUid', isEqualTo: authUid)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) {
      if (mounted) setState(() { _loading = false; _profileMissing = true; });
      return;
    }

    if (mounted) setState(() { _resolvedId = qs.docs.first.id; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      );
    }

    if (_profileMissing || _resolvedId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No linked profile found.\n'
            'Please complete registration or contact support.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    final userPath = '/Users/${_resolvedId!}';

    // ── Jobs stream: ALL jobs (ongoing, cancelled, AND completed) ──
    // Previously this filtered out Status=='Completed' on the assumption that
    // every completed job has a matching JobInvoice doc. That isn't true:
    // JobInvoice is only created after a successful FPX payment, so cash
    // jobs and any pre-invoice completions silently disappeared from history.
    // We now read every job and dedupe against the invoice stream below.
    final jobsStream = FirebaseFirestore.instance
        .collection('Jobs')
        .where('UserID', isEqualTo: userPath)
        .snapshots();

    // ── Invoice stream ──
    final invoiceStream = FirebaseFirestore.instance
        .collection('JobInvoice')
        .where('UserID', isEqualTo: userPath)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: jobsStream,
      builder: (context, jobsSnap) {
        // Handle failed-precondition (missing Firestore composite index).
        if (jobsSnap.hasError) {
          final err = jobsSnap.error.toString();
          if (err.contains('failed-precondition') ||
              err.contains('requires an index')) {
            debugPrint('DEBUG: Jobs query needs a composite index — $err');
            return _IndexPendingBanner(
              message: 'A Firestore index is being built for Jobs. '
                  'This may take a few minutes.',
            );
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: invoiceStream,
          builder: (context, invoiceSnap) {
            // Handle failed-precondition for invoices.
            if (invoiceSnap.hasError) {
              final err = invoiceSnap.error.toString();
              if (err.contains('failed-precondition') ||
                  err.contains('requires an index')) {
                debugPrint('DEBUG: Invoice query needs a composite index — $err');
                return _IndexPendingBanner(
                  message: 'A Firestore index is being built for Invoices. '
                      'This may take a few minutes.',
                );
              }
            }

            if (jobsSnap.connectionState == ConnectionState.waiting &&
                invoiceSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }

            final items = <_HistoryItem>[];

            // Invoices win where they exist (richer payload — receipt no, FPX
            // transaction details, etc.). Track which JobIDs they cover so we
            // can skip the matching Job entry below and avoid duplicates.
            final invoicedJobIds = <String>{};

            // ── Invoices → Completed (green badge) ──
            for (final doc in (invoiceSnap.data?.docs ?? [])) {
              final d = doc.data();
              final jobId = (d['JobID'] as String?)?.trim();
              if (jobId != null && jobId.isNotEmpty) invoicedJobIds.add(jobId);

              items.add(_HistoryItem(
                docId: doc.id,
                source: _HistorySource.invoice,
                serviceType: (d['ServiceType'] ?? 'Service').toString(),
                userLocation: (d['UserLocation'] ?? '').toString(),
                totalCost: _parseDouble(d['TotalCost']),
                status: 'Completed',
                date: _parseTimestamp(d['RequestedTime'] ?? d['DateRequested']),
                raw: d,
              ));
            }

            // ── Jobs → Ongoing (orange), Completed (green) or Cancelled (red) ──
            for (final doc in (jobsSnap.data?.docs ?? [])) {
              final d = doc.data();
              final status = (d['Status'] ?? 'Pending').toString();
              final isCancelled = status.toLowerCase() == 'cancelled';
              final isCompleted = status.toLowerCase() == 'completed';

              // Skip completed jobs that already have an invoice — the invoice
              // entry above represents them with the full receipt payload.
              if (isCompleted && invoicedJobIds.contains(doc.id)) continue;

              items.add(_HistoryItem(
                docId: doc.id,
                source: _HistorySource.job,
                serviceType: (d['ServiceType'] ?? 'Service').toString(),
                userLocation: (d['UserLocation'] ?? '').toString(),
                totalCost: _parseDouble(d['TotalCost']),
                status: status,
                date: isCancelled
                    ? _parseTimestamp(d['DateCancelled'] ??
                        d['DateRequested'] ??
                        d['RequestedTime'])
                    : isCompleted
                        ? _parseTimestamp(d['DateCompleted'] ??
                            d['DateRequested'] ??
                            d['RequestedTime'])
                        : _parseTimestamp(
                            d['DateRequested'] ?? d['RequestedTime']),
                raw: d,
              ));
            }

            debugPrint('DEBUG: History items found — '
                '${jobsSnap.data?.docs.length ?? 0} jobs, '
                '${invoiceSnap.data?.docs.length ?? 0} invoices');

            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No History Found',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            // Sort newest first.
            items.sort((a, b) {
              if (a.date == null && b.date == null) return 0;
              if (a.date == null) return 1;
              if (b.date == null) return -1;
              return b.date!.compareTo(a.date!);
            });

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _HistoryCard(item: items[i]),
            );
          },
        );
      },
    );
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    debugPrint('[History] WARNING: unexpected timestamp type: ${v.runtimeType} value: $v');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Banner shown while a Firestore composite index is still building
// ---------------------------------------------------------------------------

class _IndexPendingBanner extends StatelessWidget {
  final String message;
  const _IndexPendingBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orangeAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again shortly.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History card
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final dateText = item.date != null ? dateFmt.format(item.date!) : '—';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: service type + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.serviceType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: item.displayStatus,
                  isOngoing: item.isOngoing,
                  isCancelled: item.isCancelled,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Date
            Row(
              children: [
                Icon(
                  item.isOngoing
                      ? Icons.schedule
                      : Icons.check_circle_outline,
                  color: Colors.white54,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  dateText,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Cost
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  item.totalCost > 0
                      ? 'RM ${item.totalCost.toStringAsFixed(2)}'
                      : 'RM —',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            // Location
            if (item.userLocation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.userLocation,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Action row
            if (!item.isOngoing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.yellow,
                    side: const BorderSide(color: Colors.yellow),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _viewReceipt(context),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text(
                    'View Receipt',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],

            if (item.isOngoing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A0A),
                    foregroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _goToActiveJob(context),
                  icon: const Icon(Icons.navigation, size: 16),
                  label: const Text(
                    'Track Job',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],

            if (item.isCancelled) ...[
              const SizedBox(height: 10),
              Builder(builder: (_) {
                final cancelledOn = item.dateCancelled ?? item.date;
                final label = cancelledOn != null
                    ? 'Cancelled on ${DateFormat('MMM d, yyyy').format(cancelledOn)}'
                    : 'Cancelled';
                return Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFF8888),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (item.isCancelled) return;
    if (item.isOngoing) {
      _goToActiveJob(context);
    } else {
      _viewReceipt(context);
    }
  }

  void _goToActiveJob(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveJobTrackingPage(
          jobId: item.docId,
        ),
      ),
    );
  }

  Future<void> _viewReceipt(BuildContext context) async {
    // Show a blocking loader while we look for a PDF receipt.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      ),
    );

    final pdfUrl = await _resolveReceiptPdfUrl(item);

    if (!context.mounted) return;
    Navigator.pop(context); // close loader

    if (pdfUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptViewerPage(
            pdfUrl: pdfUrl,
            invoiceId: item.docId,
          ),
        ),
      );
    } else {
      // No PDF uploaded yet — fall back to the in-app receipt view.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _InvoiceDetailPage(
            invoiceId: item.docId,
            data: item.raw,
          ),
        ),
      );
    }
  }

  /// Tries the invoice doc fields, then Firebase Storage paths.
  Future<String?> _resolveReceiptPdfUrl(_HistoryItem item) async {
    for (final key in const [
      'ReceiptUrl',
      'ReceiptPdfUrl',
      'InvoiceUrl',
      'pdfUrl',
    ]) {
      final v = item.raw[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }

    final jobId = (item.raw['JobID'] as String?)?.trim();
    final ids = <String>{
      item.docId,
      if (jobId != null && jobId.isNotEmpty) jobId,
    };

    for (final id in ids) {
      for (final path in ['receipts/$id.pdf', 'invoices/$id.pdf']) {
        try {
          return await FirebaseStorage.instance.ref(path).getDownloadURL();
        } catch (_) {}
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isOngoing;
  final bool isCancelled;
  const _StatusBadge({
    required this.label,
    required this.isOngoing,
    this.isCancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    if (isCancelled) {
      bg = const Color(0xFFFF4444);
      fg = Colors.white;
    } else if (isOngoing) {
      bg = const Color(0xFF3A2E1B);
      fg = const Color(0xFFFF9800);
    } else {
      bg = const Color(0xFF1B3A1B);
      fg = const Color(0xFF4CAF50);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invoice detail page (receipt view from history)
// ---------------------------------------------------------------------------

class _InvoiceDetailPage extends StatelessWidget {
  final String invoiceId;
  final Map<String, dynamic> data;

  const _InvoiceDetailPage({
    required this.invoiceId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    final totalCost = (data['TotalCost'] ?? 0).toDouble();
    final platformFee = (data['PlatformFee'] ??
            (totalCost * InvoiceService.platformFeeRate).roundToDouble())
        .toDouble();
    final contractorEarnings = totalCost - platformFee;
    final paymentMethod = (data['PaymentMethod'] ?? '—').toString();
    final safeId = invoiceId.length >= 8
        ? invoiceId.substring(0, 8)
        : invoiceId;
    final receiptNo = (data['ReceiptNo'] ??
            'IRAMS-${safeId.toUpperCase()}')
        .toString();
    final serviceType = (data['ServiceType'] ?? 'Service').toString();
    final status = (data['Status'] ?? 'Unknown').toString();
    final userLocation = (data['UserLocation'] ?? '').toString();

    // ── Null-safe timestamp ──
    // Walks the candidate fields in order of preference. The first two come
    // from JobInvoice docs (FPX path); the next two from Jobs docs (cash /
    // admin-completed). createdAt is the camelCase mirror InvoiceService also
    // writes — kept as a final fallback for older invoices.
    Timestamp? pickTs() {
      for (final key in const [
        'CompletionTime',  // JobInvoice — when payment cleared
        'DateCompleted',   // Jobs       — when admin/contractor flipped status
        'RequestedTime',   // JobInvoice — original request
        'DateRequested',   // Jobs       — original request
        'createdAt',       // JobInvoice camelCase mirror
      ]) {
        final v = data[key];
        if (v is Timestamp) return v;
      }
      return null;
    }

    final ts = pickTs();
    final dateText = ts != null ? dateFmt.format(ts.toDate()) : '—';

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
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Success indicator
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 10),
            const Text(
              'PAYMENT COMPLETED',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Receipt card
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
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 10),

                  _row('Receipt No', receiptNo),
                  _row('Date', dateText),
                  _row('Payment Method', paymentMethod),

                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 10),

                  _row('Service', serviceType),
                  _row('Status', status),
                  if (userLocation.isNotEmpty) _row('Location', userLocation),

                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 10),

                  _row('Subtotal',
                      'RM ${contractorEarnings.toStringAsFixed(2)}'),
                  _row(
                      'Platform Fee (${(InvoiceService.platformFeeRate * 100).toInt()}%)',
                      'RM ${platformFee.toStringAsFixed(2)}'),

                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF555555), thickness: 1.5),
                  const SizedBox(height: 8),

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
                        'RM ${totalCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'DONE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
}
