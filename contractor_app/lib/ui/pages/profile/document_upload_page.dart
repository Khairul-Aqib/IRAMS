import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

// =============================================================================
// Document slot model
// =============================================================================

class _DocSlot {
  final String label;
  final String description;
  final IconData icon;
  final String firestoreField; // URL field saved on the Contractor document
  final String storageKey; // Filename stem in Firebase Storage
  final bool cameraOnly; // When true, skip gallery — live capture only
  final bool requiresExpiry; // When true, user must pick an expiry date

  String? existingUrl; // Previously uploaded URL (loaded from Firestore)
  XFile? newFile; // Newly picked file (not yet uploaded)
  DateTime? expiryDate; // Expiry date for time-sensitive documents

  _DocSlot({
    required this.label,
    required this.description,
    required this.icon,
    required this.firestoreField,
    required this.storageKey,
    this.cameraOnly = false,
    this.requiresExpiry = false,
  });

  bool get hasContent => newFile != null || existingUrl != null;
}

// =============================================================================
// Page
// =============================================================================

class DocumentUploadPage extends StatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  final _picker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;

  late final List<_DocSlot> _slots = [
    _DocSlot(
      label: 'Live Selfie',
      description: 'Take a clear selfie — pending Admin approval before display',
      icon: Icons.face,
      firestoreField: 'SubmittedSelfieUrl',
      storageKey: 'profile_picture',
      cameraOnly: true,
    ),
    _DocSlot(
      label: 'NRIC (MyKad) Front',
      description: 'Front of your MyKad / identity card',
      icon: Icons.badge,
      firestoreField: 'IcFrontUrl',
      storageKey: 'ic_front',
    ),
    _DocSlot(
      label: 'NRIC (MyKad) Back',
      description: 'Back of your MyKad / identity card',
      icon: Icons.badge_outlined,
      firestoreField: 'IcBackUrl',
      storageKey: 'ic_back',
    ),
    _DocSlot(
      label: 'Driving License (GDL/Class E)',
      description: 'Valid JPJ-issued driving licence',
      icon: Icons.credit_card,
      firestoreField: 'GdlLicenseUrl',
      storageKey: 'gdl_license',
      requiresExpiry: true,
    ),
    _DocSlot(
      label: 'Vehicle Grant (VOC/Geran)',
      description: 'Vehicle ownership registration grant',
      icon: Icons.directions_car,
      firestoreField: 'VehicleGrantUrl',
      storageKey: 'vehicle_grant',
      requiresExpiry: true,
    ),
    _DocSlot(
      label: 'PUSPAKOM Inspection Cert',
      description: 'Valid PUSPAKOM vehicle inspection report',
      icon: Icons.verified_user,
      firestoreField: 'PuspakomUrl',
      storageKey: 'puspakom',
      requiresExpiry: true,
    ),
  ];

  bool get _allComplete => _slots.every((s) => s.hasContent);
  int get _completedCount => _slots.where((s) => s.hasContent).length;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadExisting();
    _retrieveLostData();
  }

  /// Recovers a photo captured just before Android killed the app to free RAM
  /// for the native camera activity. Assigns to the first incomplete slot.
  Future<void> _retrieveLostData() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;

      final target = _slots.cast<_DocSlot?>().firstWhere(
            (s) => !s!.hasContent,
            orElse: () => null,
          );
      if (target == null) return;

      setState(() => target.newFile = response.file);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recovered photo assigned to "${target.label}"'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('retrieveLostData failed: $e');
    }
  }

  Future<void> _loadExisting() async {
    try {
      final id = await FirestoreService.instance.getMyContractorDocId();
      if (id != null) {
        final doc =
            await FirestoreService.instance.contractors.doc(id).get();
        final d = doc.data() ?? {};
        final compliance = d['ComplianceDocumentsMetadata'];

        for (final slot in _slots) {
          // Try ComplianceDocumentsMetadata map first (keyed by storageKey slug)
          if (!slot.cameraOnly && compliance is Map) {
            final entry = compliance[slot.storageKey];
            if (entry is Map &&
                (entry['url']?.toString() ?? '').isNotEmpty) {
              slot.existingUrl = entry['url'].toString();
              continue;
            }
          }
          // Fallback to legacy flat field
          slot.existingUrl = d[slot.firestoreField]?.toString();
        }
      }
    } catch (_) {
      // Non-fatal — proceed with empty slots
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Image picker — camera / gallery bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(_DocSlot slot) async {
    // Camera-only slots (e.g. selfie) skip the source picker
    if (slot.cameraOnly) {
      try {
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 80,
          maxWidth: 1920,
        );
        if (picked != null && mounted) {
          setState(() => slot.newFile = picked);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open camera: $e'),
              backgroundColor: Colors.redAccent,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kYellow.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: kYellow),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text(
                  'Use your camera to capture the document',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const Divider(color: kBorder, height: 1, indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kYellow.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: kYellow),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text(
                  'Select an existing photo from your device',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return; // User dismissed the sheet

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => slot.newFile = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Could not open camera: $e'
                  : 'Could not open gallery: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Expiry date picker
  // ---------------------------------------------------------------------------

  Future<void> _pickExpiryDate(_DocSlot slot) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: slot.expiryDate ?? now.add(const Duration(days: 365)),
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
      setState(() => slot.expiryDate = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit — upload to Storage, update Firestore, pop
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_submitting) return;

    // Validate all 5 documents
    if (!_allComplete) {
      final missing = _slots.where((s) => !s.hasContent).map((s) => s.label);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Missing: ${missing.join(', ')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate expiry dates for time-sensitive documents
    final missingExpiry = _slots
        .where((s) => s.requiresExpiry && s.hasContent && s.expiryDate == null)
        .map((s) => s.label);
    if (missingExpiry.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select an expiry date for: ${missingExpiry.join(', ')}',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final contractorId =
          await FirestoreService.instance.getMyContractorDocId();
      if (contractorId == null) throw Exception('Contractor not found');

      // Upload all newly selected files concurrently
      final updates = <String, dynamic>{};
      await Future.wait(_slots.map((slot) async {
        if (slot.newFile != null) {
          final String url;
          if (slot.cameraOnly) {
            // Selfie → dedicated profile_pictures path
            url = await StorageService.instance.uploadProfilePhoto(
              contractorId: contractorId,
              file: slot.newFile!,
            );
            updates[slot.firestoreField] = url;
            // Dedicated selfie status (not tied to global VerificationStatus)
            updates['SelfieStatus'] = 'uploaded';
          } else {
            url = await StorageService.instance.uploadVerificationDoc(
              contractorId: contractorId,
              docKey: slot.storageKey,
              file: slot.newFile!,
            );
            // New schema: field-level dot-notation so only this document
            // key is modified — sibling entries are untouched.
            final prefix = 'ComplianceDocumentsMetadata.${slot.storageKey}';
            updates['$prefix.url'] = url;
            updates['$prefix.status'] = 'under_review';
            updates['$prefix.uploadedAt'] = FieldValue.serverTimestamp();
            if (slot.requiresExpiry && slot.expiryDate != null) {
              updates['$prefix.expiry'] =
                  '${slot.expiryDate!.year}-${slot.expiryDate!.month.toString().padLeft(2, '0')}-${slot.expiryDate!.day.toString().padLeft(2, '0')}';
            }
            // Legacy flat field for backwards compatibility
            updates[slot.firestoreField] = url;
          }
        }
        // Unchanged existing docs are left as-is in Firestore (merge write)
      }));

      updates['VerificationStatus'] = 'under_review';
      updates['LastSubmittedAt'] = FieldValue.serverTimestamp();

      await FirestoreService.instance.updateContractorProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Documents submitted for admin review'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: const Text(
          'Upload Documents',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: kYellow),
                )
              : _buildBody(),
          // Loading overlay while submitting
          if (_submitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kYellow),
                    SizedBox(height: 20),
                    Text(
                      'Uploading documents...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Please do not close the app',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _loading ? null : _buildSubmitBar(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildIntroCard(),
        const SizedBox(height: 16),
        _buildProgressBar(),
        const SizedBox(height: 20),
        ..._slots.map(
          (slot) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDocCard(slot),
          ),
        ),
        const SizedBox(height: 80), // clearance for submit bar
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Intro card
  // ---------------------------------------------------------------------------

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_ind, color: kYellow, size: 22),
              SizedBox(width: 10),
              Text(
                'Required Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Upload all documents below to submit your profile for '
            'verification. Your selfie must be a live photo from the camera.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress bar
  // ---------------------------------------------------------------------------

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_completedCount of ${_slots.length} documents',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_allComplete)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'All ready',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _slots.isEmpty ? 0 : _completedCount / _slots.length,
            backgroundColor: kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              _allComplete ? Colors.green : kYellow,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Document card
  // ---------------------------------------------------------------------------

  Widget _buildDocCard(_DocSlot slot) {
    final hasNew = slot.newFile != null;
    final hasExisting = slot.existingUrl != null;
    final isComplete = slot.hasContent;

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? Colors.green.withAlpha(130) : kBorder,
          width: isComplete ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green.withAlpha(30)
                        : kYellow.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    slot.icon,
                    color: isComplete ? Colors.green : kYellow,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        slot.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isComplete)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),

          // ── Image preview ──
          if (hasNew)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.file(
                File(slot.newFile!.path),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (hasExisting)
            Stack(
              children: [
                Image.network(
                  slot.existingUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(
                    'Previously uploaded (preview unavailable)',
                    Colors.white38,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Previously uploaded',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ),
              ],
            )
          else
            _imagePlaceholder('No document selected', Colors.white24),

          // ── Expiry date picker (time-sensitive documents only) ──
          if (slot.requiresExpiry && isComplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                onTap: _submitting ? null : () => _pickExpiryDate(slot),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: slot.expiryDate != null
                          ? kYellow.withAlpha(100)
                          : kBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: slot.expiryDate != null
                            ? kYellow
                            : Colors.white38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          slot.expiryDate != null
                              ? 'Expires: ${DateFormat('dd/MM/yyyy').format(slot.expiryDate!)}'
                              : 'Select Expiry Date',
                          style: TextStyle(
                            color: slot.expiryDate != null
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 13,
                            fontWeight: slot.expiryDate != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: Colors.white38),
                    ],
                  ),
                ),
              ),
            ),

          // ── Action button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: isComplete
                  ? OutlinedButton.icon(
                      onPressed: _submitting ? null : () => _pickImage(slot),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retake / Replace'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kYellow,
                        side: BorderSide(color: kYellow.withAlpha(150)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _submitting ? null : () => _pickImage(slot),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(String text, Color textColor) {
    return Container(
      height: 120,
      width: double.infinity,
      color: kBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 36, color: textColor),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: textColor, fontSize: 12)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Submit bar
  // ---------------------------------------------------------------------------

  Widget _buildSubmitBar() {
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
          child: ElevatedButton(
            onPressed: (_allComplete && !_submitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
              foregroundColor: Colors.black,
              disabledBackgroundColor: kYellow.withAlpha(60),
              shape: const StadiumBorder(),
            ),
            child: Text(
              _allComplete
                  ? 'Submit for Verification'
                  : 'Upload All Documents ($_completedCount/${_slots.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
