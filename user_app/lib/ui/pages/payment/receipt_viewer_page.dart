import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Displays a receipt/invoice PDF. Accepts either a direct [pdfUrl] or a
/// [jobId]/[invoiceId] that we use to resolve a download URL from either
/// the `JobInvoice` document or Firebase Storage at `receipts/{id}.pdf`.
class ReceiptViewerPage extends StatefulWidget {
  final String? pdfUrl;
  final String? jobId;
  final String? invoiceId;

  const ReceiptViewerPage({
    super.key,
    this.pdfUrl,
    this.jobId,
    this.invoiceId,
  }) : assert(pdfUrl != null || jobId != null || invoiceId != null,
            'Provide pdfUrl, jobId, or invoiceId');

  @override
  State<ReceiptViewerPage> createState() => _ReceiptViewerPageState();
}

class _ReceiptViewerPageState extends State<ReceiptViewerPage> {
  String? _resolvedUrl;
  String? _error;
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _resolvePdfUrl();
  }

  Future<void> _resolvePdfUrl() async {
    try {
      final direct = widget.pdfUrl?.trim();
      if (direct != null && direct.isNotEmpty) {
        setState(() {
          _resolvedUrl = direct;
          _loading = false;
        });
        return;
      }

      final id = (widget.invoiceId ?? widget.jobId ?? '').trim();
      if (id.isEmpty) {
        setState(() {
          _error = 'No receipt identifier provided.';
          _loading = false;
        });
        return;
      }

      final url = await _findReceiptUrl(id);
      if (!mounted) return;
      if (url == null) {
        setState(() {
          _error = 'No PDF receipt available for this job yet.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _resolvedUrl = url;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load receipt: $e';
        _loading = false;
      });
    }
  }

  /// Tries (in order): `JobInvoice/{invoiceId}.ReceiptUrl`,
  /// JobInvoice where JobID==id, then Firebase Storage `receipts/{id}.pdf`.
  Future<String?> _findReceiptUrl(String id) async {
    final db = FirebaseFirestore.instance;

    // 1) Direct invoice doc lookup
    try {
      final doc = await db.collection('JobInvoice').doc(id).get();
      if (doc.exists) {
        final url = _extractPdfField(doc.data());
        if (url != null) return url;
      }
    } catch (_) {}

    // 2) Invoice queried by JobID
    try {
      final qs = await db
          .collection('JobInvoice')
          .where('JobID', isEqualTo: id)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        final url = _extractPdfField(qs.docs.first.data());
        if (url != null) return url;
      }
    } catch (_) {}

    // 3) Firebase Storage fallback — try common filenames.
    final candidates = ['receipts/$id.pdf', 'invoices/$id.pdf'];
    for (final path in candidates) {
      try {
        return await FirebaseStorage.instance.ref(path).getDownloadURL();
      } catch (_) {
        // try next
      }
    }

    return null;
  }

  String? _extractPdfField(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in ['ReceiptUrl', 'ReceiptPdfUrl', 'InvoiceUrl', 'pdfUrl']) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  Future<void> _downloadPdf() async {
    final url = _resolvedUrl;
    if (url == null || _downloading) return;

    setState(() => _downloading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'IRAMS-Receipt-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savePath = '${dir.path}${Platform.pathSeparator}$fileName';

      await Dio().download(url, savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Saved to $savePath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Download failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
        actions: [
          if (_resolvedUrl != null)
            IconButton(
              tooltip: 'Download',
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.yellow,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.yellow),
              onPressed: _downloading ? null : _downloadPdf,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      );
    }

    if (_error != null || _resolvedUrl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined,
                  color: Colors.orangeAccent, size: 56),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unable to load receipt.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.yellow,
                  side: const BorderSide(color: Colors.yellow),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return SfPdfViewer.network(_resolvedUrl!);
  }
}
