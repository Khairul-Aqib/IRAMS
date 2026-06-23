import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

/// Dedicated form page for uploading (or re-uploading) a compliance document.
/// Collects the image and an optional expiry date before submitting.
class DocumentUploadFormPage extends StatefulWidget {
  final String contractorId;
  final String documentKey;
  final String documentTitle;
  final bool requiresExpiry;
  final bool cameraOnly;
  final String? rejectionReason;

  const DocumentUploadFormPage({
    super.key,
    required this.contractorId,
    required this.documentKey,
    required this.documentTitle,
    required this.requiresExpiry,
    this.cameraOnly = false,
    this.rejectionReason,
  });

  @override
  State<DocumentUploadFormPage> createState() => _DocumentUploadFormPageState();
}

class _DocumentUploadFormPageState extends State<DocumentUploadFormPage> {
  XFile? _selectedFile;
  DateTime? _expiryDate;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _retrieveLostData();
  }

  // ── Android lost-data recovery ──────────────────────────────────────────

  Future<void> _retrieveLostData() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;
      setState(() => _selectedFile = response.file);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo recovered from previous session.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('retrieveLostData failed: $e');
    }
  }

  // ── Image picking ───────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    // Camera-only documents (e.g. Live Selfie) skip the source picker
    if (widget.cameraOnly) {
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 80,
          maxWidth: 1920,
        );
        if (file != null && mounted) {
          setState(() => _selectedFile = file);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open camera: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Select Photo',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: kYellow),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const Divider(color: kBorder, height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.photo_library, color: kYellow),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (file != null && mounted) {
      setState(() => _selectedFile = file);
    }
  }

  // ── Expiry date picking ─────────────────────────────────────────────────

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Select document expiry date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kYellow,
            surface: kCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  // ── Submission ──────────────────────────────────────────────────────────

  bool get _canSubmit {
    if (_selectedFile == null) return false;
    if (widget.requiresExpiry && _expiryDate == null) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedFile == null
                ? 'Please select a photo first.'
                : 'Please select an expiry date.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Selfie uses a dedicated storage path; all other docs share one.
      final String url;
      if (widget.cameraOnly) {
        url = await StorageService.instance.uploadProfilePhoto(
          contractorId: widget.contractorId,
          file: _selectedFile!,
        );
      } else {
        url = await StorageService.instance.uploadVerificationDoc(
          contractorId: widget.contractorId,
          docKey: widget.documentKey,
          file: _selectedFile!,
        );
      }

      // Use field-level dot-notation so only the targeted document key
      // is modified — other sibling entries are untouched.
      final prefix = 'ComplianceDocumentsMetadata.${widget.documentKey}';
      final expiryStr = _expiryDate != null
          ? '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
          : null;

      // Map slug → legacy top-level Firestore field name so all readers
      // (preview fallback, admin dashboard, etc.) can find the image.
      const slugToLegacyField = {
        'profile_picture': 'SubmittedSelfieUrl',
        'ic_front': 'IcFrontUrl',
        'ic_back': 'IcBackUrl',
        'gdl_license': 'GdlLicenseUrl',
        'vehicle_grant': 'VehicleGrantUrl',
        'puspakom': 'PuspakomUrl',
      };

      final payload = <String, dynamic>{
        // Nested compliance metadata — individual fields only
        '$prefix.url': url,
        '$prefix.status': 'under_review',
        if (expiryStr != null) '$prefix.expiry': expiryStr,
        // Legacy top-level URL field
        if (slugToLegacyField.containsKey(widget.documentKey))
          slugToLegacyField[widget.documentKey]!: url,
        // Selfie gets its own dedicated status field
        if (widget.documentKey == 'profile_picture')
          'SelfieStatus': 'uploaded',
        // NOTE: VerificationStatus is NOT flipped here. The contractor
        // must tap "Submit Updates for Review" on the compliance page to
        // batch-notify the admin, preventing per-document spam.
        'LastSubmittedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.instance.updateContractorProfile(payload);

      if (!mounted) return;
      // Reset spinner before popping — pop unmounts the widget, so a
      // finally-based reset would see mounted == false and skip it.
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.documentTitle} updated successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: Text(
          'Upload ${widget.documentTitle}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Rejection reason banner ──
                  if (widget.rejectionReason != null &&
                      widget.rejectionReason!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.redAccent.withAlpha(80)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Please fix the following issue:',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.rejectionReason!,
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
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Image picker zone ──
                  _buildImagePicker(),
                  const SizedBox(height: 20),

                  // ── Expiry date field ──
                  if (widget.requiresExpiry) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Expiry Date',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildExpiryField(),
                  ],
                ],
              ),
            ),
          ),

          // ── Submit button ──
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ── Image picker widget ─────────────────────────────────────────────────

  Widget _buildImagePicker() {
    if (_selectedFile != null) {
      // Show selected image preview with a change button
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(_selectedFile!.path),
                  fit: BoxFit.cover,
                ),
                // Overlay to re-pick
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Change',
                          style: TextStyle(color: Colors.white, fontSize: 12),
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

    // Dashed-border empty state
    return GestureDetector(
      onTap: _pickImage,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: Colors.white24, radius: 12),
        child: Container(
          height: 220,
          width: double.infinity,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kYellow.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_a_photo, color: kYellow, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                widget.cameraOnly
                    ? 'Tap to take a selfie'
                    : 'Tap to select a photo',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.cameraOnly ? 'Front camera only' : 'Camera or Gallery',
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expiry date field ───────────────────────────────────────────────────

  Widget _buildExpiryField() {
    final hasDate = _expiryDate != null;
    final display =
        hasDate ? DateFormat('dd MMM yyyy').format(_expiryDate!) : '';

    return GestureDetector(
      onTap: _pickExpiryDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: kYellow),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate ? display : 'Select Expiry Date',
                style: TextStyle(
                  color: hasDate ? Colors.white : Colors.white38,
                  fontSize: 14,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // ── Submit button ───────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
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
            onPressed: _isUploading ? null : _submit,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black),
                  )
                : Icon(
                    _canSubmit ? Icons.cloud_upload : Icons.cloud_upload_outlined,
                    size: 20,
                  ),
            label: Text(
              _isUploading ? 'Uploading...' : 'Submit Document',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit ? kYellow : kYellow.withAlpha(80),
              foregroundColor: Colors.black,
              disabledBackgroundColor: kYellow.withAlpha(80),
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

// ── Dashed border painter ─────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 1.5;
    const double dashWidth = 8;
    const double dashGap = 5;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
