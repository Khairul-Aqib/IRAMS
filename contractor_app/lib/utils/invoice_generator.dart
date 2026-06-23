import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Represents a single completed job entry on the invoice.
class InvoiceJobEntry {
  final String serviceType;
  final num amount;
  final DateTime? date;

  const InvoiceJobEntry({
    required this.serviceType,
    required this.amount,
    this.date,
  });
}

/// Generates a professional PDF invoice for the IRAMS Contractor App.
class InvoiceGenerator {
  InvoiceGenerator._();

  /// Builds and returns a PDF as [Uint8List].
  ///
  /// [contractorName] — contractor's full name (e.g. "Ahmad bin Ali")
  /// [companyName]    — company / trading name
  /// [month]          — the month being invoiced (first day of the month)
  /// [entries]        — list of completed jobs for that month
  static Future<Uint8List> generateInvoice({
    required String contractorName,
    required String companyName,
    required DateTime month,
    required List<InvoiceJobEntry> entries,
  }) async {
    final pdf = pw.Document();

    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final total = entries.fold<num>(0, (s, e) => s + e.amount);

    // ── Colour palette (dark yellow brand) ──────────────────────────────────
    const accent = PdfColor.fromInt(0xFFF6C000);
    const darkBg = PdfColor.fromInt(0xFF1A1A1A);
    const textDark = PdfColor.fromInt(0xFF1A1A1A);
    const textLight = PdfColor.fromInt(0xFF555555);
    const rowAlt = PdfColor.fromInt(0xFFF9F5E8);

    try {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Header ────────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const pw.BoxDecoration(color: darkBg),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IRAMS',
                      style: pw.TextStyle(
                        color: accent,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Intelligent Roadside Assistance\nManagement System',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'OFFICIAL RECEIPT',
                      style: pw.TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      monthLabel,
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Generated: $generatedAt',
                      style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── Contractor Info ────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILLED BY',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: textLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      contractorName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    if (companyName.isNotEmpty && companyName != contractorName)
                      pw.Text(
                        companyName,
                        style: const pw.TextStyle(fontSize: 11, color: textLight),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TOTAL EARNINGS',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: textLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'RM ${total.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    pw.Text(
                      '${entries.length} job${entries.length == 1 ? '' : 's'} completed',
                      style: const pw.TextStyle(fontSize: 10, color: textLight),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── Table Header ──────────────────────────────────────────────────
          if (entries.isEmpty)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 40),
                child: pw.Text(
                  'No completed jobs for this period.',
                  style: const pw.TextStyle(color: textLight, fontSize: 12),
                ),
              ),
            )
          else ...[
            pw.Text(
              'JOB BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: textLight,
                letterSpacing: 1.5,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: null,
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(2.5),
                2: pw.FlexColumnWidth(1),
              },
              children: [
                // Table header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: darkBg),
                  children: [
                    _headerCell('DATE'),
                    _headerCell('SERVICE TYPE'),
                    _headerCell('AMOUNT', alignRight: true),
                  ],
                ),
                // Data rows
                ...entries.asMap().entries.map((mapEntry) {
                  final i = mapEntry.key;
                  final e = mapEntry.value;
                  final dateStr = e.date != null
                      ? DateFormat('dd MMM yyyy').format(e.date!.toLocal())
                      : '—';
                  final bg = i.isOdd ? rowAlt : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _dataCell(dateStr),
                      _dataCell(e.serviceType),
                      _dataCell(
                        'RM ${e.amount.toStringAsFixed(2)}',
                        alignRight: true,
                        bold: true,
                      ),
                    ],
                  );
                }),
                // Total row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: darkBg),
                  children: [
                    _footerCell(''),
                    _footerCell('TOTAL'),
                    _footerCell(
                      'RM ${total.toStringAsFixed(2)}',
                      alignRight: true,
                      accent: true,
                    ),
                  ],
                ),
              ],
            ),
          ],

          pw.SizedBox(height: 32),

          // ── Footer ────────────────────────────────────────────────────────
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'This is an auto-generated receipt from the IRAMS Contractor App. '
              'For disputes, contact support@irams.my.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: textLight),
            ),
          ),
        ],
      ),
    );

    return await pdf.save();
    } catch (e, st) {
      throw Exception(
        'PDF generation failed — unable to build invoice document. '
        'Cause: $e\n$st',
      );
    }
  }

  // ── Helper cells ──────────────────────────────────────────────────────────

  static pw.Widget _headerCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(
    String text, {
    bool alignRight = false,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: const PdfColor.fromInt(0xFF1A1A1A),
        ),
      ),
    );
  }

  static pw.Widget _footerCell(
    String text, {
    bool alignRight = false,
    bool accent = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: accent ? const PdfColor.fromInt(0xFFF6C000) : PdfColors.white,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}
