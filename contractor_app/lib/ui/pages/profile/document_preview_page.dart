import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../services/firestore_service.dart';
import 'document_upload_form_page.dart';

/// Master-detail preview page for a single compliance document.
/// Shows the uploaded image (or a placeholder) and allows in-place re-upload.
class DocumentPreviewPage extends StatefulWidget {
  final String documentKey; // e.g. 'ic_front'
  final String documentTitle; // e.g. 'NRIC (MyKad) Front'

  const DocumentPreviewPage({
    super.key,
    required this.documentKey,
    required this.documentTitle,
  });

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  static const _timeSensitiveSlugs = {
    'gdl_license',
    'vehicle_grant',
    'puspakom',
  };

  static const _cameraOnlySlugs = {
    'profile_picture',
  };

  void _openUploadForm(String contractorId, {String? rejectionReason}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentUploadFormPage(
          contractorId: contractorId,
          documentKey: widget.documentKey,
          documentTitle: widget.documentTitle,
          requiresExpiry: _timeSensitiveSlugs.contains(widget.documentKey),
          cameraOnly: _cameraOnlySlugs.contains(widget.documentKey),
          rejectionReason: rejectionReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: Text(
          widget.documentTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: FutureBuilder<String?>(
        future: FirestoreService.instance.getMyContractorDocId(),
        builder: (context, idSnap) {
          if (!idSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: kYellow));
          }
          final contractorId = idSnap.data!;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.instance.contractors
                .doc(contractorId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: kYellow));
              }

              final data = snap.data?.data() ?? {};
              final metadata = _extractMetadata(data);
              final url = metadata['url']?.toString() ?? '';
              final status = metadata['status']?.toString() ?? 'missing';
              final expiry = metadata['expiry']?.toString();
              final docNumber = metadata['docNumber']?.toString();
              final rejectionReason =
                  metadata['rejectionReason']?.toString() ??
                  metadata['reason']?.toString();

              return Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Status chip
                        _buildStatusChip(status),
                        const SizedBox(height: 16),

                        // Rejection reason banner
                        if (status == 'rejected' &&
                            rejectionReason != null &&
                            rejectionReason.isNotEmpty) ...[
                          _buildRejectionBanner(rejectionReason),
                          const SizedBox(height: 16),
                        ],

                        // Document number card (if present)
                        if (docNumber != null && docNumber.isNotEmpty) ...[
                          _buildDocNumberCard(docNumber),
                          const SizedBox(height: 16),
                        ],

                        // Thumbnail preview (tap for lightbox)
                        _buildThumbnail(url),

                        // Expiry date row (below the thumbnail)
                        if (expiry != null && expiry.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildExpiryRow(expiry),
                        ],
                      ],
                    ),
                  ),

                  // Bottom action button
                  _buildBottomButton(contractorId,
                      rejectionReason: status == 'rejected'
                          ? rejectionReason
                          : null),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, dynamic> _extractMetadata(Map<String, dynamic> data) {
    // Try new compliance metadata map first
    final complianceRaw = data['ComplianceDocumentsMetadata'];
    if (complianceRaw is Map && complianceRaw.containsKey(widget.documentKey)) {
      final entry = complianceRaw[widget.documentKey];
      if (entry is Map) return Map<String, dynamic>.from(entry);
    }

    // Fallback to legacy top-level URL fields
    const legacyFields = {
      'profile_picture': 'SubmittedSelfieUrl',
      'ic_front': 'IcFrontUrl',
      'ic_back': 'IcBackUrl',
      'gdl_license': 'GdlLicenseUrl',
      'vehicle_grant': 'VehicleGrantUrl',
      'puspakom': 'PuspakomUrl',
    };
    final legacyKey = legacyFields[widget.documentKey];
    if (legacyKey != null) {
      final url = data[legacyKey]?.toString() ?? '';
      if (url.isNotEmpty) {
        return {'url': url, 'status': 'uploaded'};
      }
    }

    return {};
  }

  Widget _buildStatusChip(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'under_review':
        color = Colors.orange;
        label = 'Under Review';
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = 'Requires Update';
        break;
      case 'uploaded':
        color = Colors.teal;
        label = 'Uploaded';
        break;
      default:
        color = Colors.white38;
        label = 'Not Uploaded';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == 'approved'
                  ? Icons.check_circle
                  : status == 'rejected'
                      ? Icons.cancel
                      : Icons.info_outline,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionBanner(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rejection Reason',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String url) {
    if (url.isEmpty) {
      // Placeholder
      return Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner, size: 56, color: Colors.white24),
            SizedBox(height: 14),
            Text(
              'No document uploaded yet.',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Tap "Update Document" below to upload.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Thumbnail with gradient overlay — tap opens fullscreen lightbox
    return GestureDetector(
      onTap: () => _openLightbox(url),
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover-cropped thumbnail
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: kCard,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: kYellow,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: kCard,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.white24),
                      SizedBox(height: 10),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom gradient overlay with hint text
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.zoom_in, size: 16, color: Colors.white70),
                      SizedBox(width: 6),
                      Text(
                        'Tap to view full screen',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLightbox(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.documentTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: kYellow,
                      strokeWidth: 2.5,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 56, color: Colors.white24),
                    SizedBox(height: 12),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocNumberCard(String docNumber) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.numbers, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          const Text(
            'Document Number: ',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            docNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryRow(String expiry) {
    DateTime? parsed = DateTime.tryParse(expiry);
    final bool isExpired =
        parsed != null && parsed.isBefore(DateTime.now());
    final String display =
        parsed != null ? DateFormat('dd MMM yyyy').format(parsed) : expiry;
    final Color dateColor = isExpired ? Colors.redAccent : Colors.white70;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? Colors.redAccent.withAlpha(80) : kBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 16, color: dateColor),
          const SizedBox(width: 8),
          Text(
            'Expiry Date:  $display',
            style: TextStyle(
              color: dateColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isExpired) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'EXPIRED',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButton(String contractorId, {String? rejectionReason}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _openUploadForm(contractorId,
                rejectionReason: rejectionReason),
            icon: const Icon(Icons.upload_file, size: 20),
            label: const Text(
              'Update Document',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
