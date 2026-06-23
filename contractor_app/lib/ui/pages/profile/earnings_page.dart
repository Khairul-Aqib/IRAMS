import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/firestore_service.dart';
import '../../../ui/widgets/app_scaffold.dart';
import '../../../core/theme.dart';
import '../../../utils/invoice_generator.dart';
import '../earnings/invoice_preview_page.dart';
import 'job_history_detail_page.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<_InvoiceEntry>? _entries;
  bool _isLoading = false;
  String? _error;

  // Contractor info for the PDF header
  String _contractorName = '';
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    _loadContractorInfo();
    _loadEarnings();
  }

  /// Fetches contractor name + company name once for use in the invoice PDF.
  Future<void> _loadContractorInfo() async {
    try {
      final id = await FirestoreService.instance.getMyContractorDocId();
      if (id == null || !mounted) return;
      final doc = await FirestoreService.instance.contractorDocRef(id).get();
      final data = doc.data();
      if (data == null || !mounted) return;
      setState(() {
        _contractorName = (data['FullName'] ?? '').toString();
        _companyName = (data['CompanyName'] ?? '').toString();
      });
    } catch (e) {
      // Non-critical — PDF will show fallback name if this fails.
      debugPrint('Failed to load contractor info: $e');
    }
  }

  Future<void> _loadEarnings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final contractorId = await FirestoreService.instance.getMyContractorDocId();
      if (contractorId == null) {
        throw 'No contractor ID found. Please logout and login again.';
      }

      final startDate = _month;
      final endDate = DateTime(_month.year, _month.month + 1, 1);

      final docs = await FirestoreService.instance.getMyInvoicesByMonth(
        startDate: startDate,
        endDate: endDate,
      );

      final entries = <_InvoiceEntry>[];
      for (final doc in docs) {
        final data = doc.data();
        if (data == null) continue;

        final cost = _parseNumber(data['TotalCost']);
        final svc = (data['ServiceType'] ?? 'Unknown Service').toString();
        final ts = data['RequestedTime'];
        DateTime? date;
        if (ts != null) {
          try {
            date = (ts as dynamic).toDate() as DateTime;
          } catch (_) {}
        }
        entries.add(_InvoiceEntry(
          id: doc.id,
          serviceType: svc,
          amount: cost,
          date: date,
          jobId: (data['JobID'] ?? '').toString(),
          paymentMethod: (data['PaymentMethod'] ?? '').toString(),
          commission: _parseNumber(data['Commission']),
          earning: _parseNumber(data['ContractorEarning']),
        ));
      }

      // Sort newest first
      entries.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('EarningsPage error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  num _parseNumber(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _entries = null;
    });
    _loadEarnings();
  }

  /// Generates the PDF and navigates to [InvoicePreviewPage].
  Future<void> _downloadInvoice() async {
    final entries = _entries;
    if (entries == null || entries.isEmpty) return;

    // Show loading overlay while generating
    setState(() => _generatingPdf = true);
    try {
      final jobEntries = entries
          .map((e) => InvoiceJobEntry(
                serviceType: e.serviceType,
                amount: e.amount,
                date: e.date,
              ))
          .toList();

      final pdfBytes = await InvoiceGenerator.generateInvoice(
        contractorName: _contractorName.isEmpty ? 'Contractor' : _contractorName,
        companyName: _companyName,
        month: _month,
        entries: jobEntries,
      );

      if (!mounted) return;

      final monthLabel = DateFormat('MMM yyyy').format(_month);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoicePreviewPage(
            pdfBytes: pdfBytes,
            title: 'Invoice — $monthLabel',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('PDF generation error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate invoice. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  bool _generatingPdf = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Earnings & History',
      child: Stack(
        children: [
          Column(
            children: [
              // Month Navigator
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isLoading ? null : () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous month',
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('MMM yyyy').format(_month),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next month',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(child: _buildContent()),
            ],
          ),

          // PDF generation loading overlay
          if (_generatingPdf)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kYellow),
                    SizedBox(height: 16),
                    Text(
                      'Generating PDF…',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kYellow),
            SizedBox(height: 16),
            Text('Loading earnings...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Failed to load earnings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadEarnings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries == null) return const Center(child: Text('No data'));

    final entries = _entries!;
    final total = entries.fold<num>(0, (sum, e) => sum + e.amount);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Total Earnings Card
        Card(
          color: kYellow.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Total Earnings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'RM ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: kYellow,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${entries.length} completed job${entries.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 80, color: Colors.white24),
                SizedBox(height: 16),
                Text(
                  'No completed jobs this month',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Complete jobs to earn money',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Completed Jobs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ),
          ...entries.map((e) => _buildJobCard(e)),
          const SizedBox(height: 16),

          // Download Invoice Button — real PDF generation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: _generatingPdf ? null : _downloadInvoice,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download Invoice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kYellow,
                side: const BorderSide(color: kYellow),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJobCard(_InvoiceEntry e) {
    final dateStr = e.date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(e.date!.toLocal())
        : 'Date unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobHistoryDetailPage(
                jobId: e.jobId.isNotEmpty ? e.jobId : e.id,
                serviceType: e.serviceType,
                totalCost: e.amount,
                commission: e.commission,
                earning: e.earning,
                paymentMethod: e.paymentMethod,
                completedAt: e.date,
              ),
            ),
          );
        },
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kYellow.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: kYellow.withOpacity(0.4)),
            ),
            child: const Icon(Icons.check_circle_outline, color: kYellow, size: 20),
          ),
          title: Text(e.serviceType, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(dateStr, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RM ${e.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: kYellow,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceEntry {
  final String id;
  final String serviceType;
  final num amount;
  final DateTime? date;
  final String jobId;
  final String paymentMethod;
  final num commission;
  final num earning;

  _InvoiceEntry({
    required this.id,
    required this.serviceType,
    required this.amount,
    this.date,
    this.jobId = '',
    this.paymentMethod = '',
    this.commission = 0,
    this.earning = 0,
  });
}
