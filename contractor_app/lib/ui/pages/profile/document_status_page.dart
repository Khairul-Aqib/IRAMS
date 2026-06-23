import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/contractor.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import 'document_preview_page.dart';

/// Full self-service Compliance Documents hub.
/// Sections: Profile, Compliance Documents (CRUD).
class DocumentStatusPage extends StatelessWidget {
  const DocumentStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: const Text(
          'Compliance Documents',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: StreamBuilder<Contractor?>(
        stream: FirestoreService.instance.watchMyContractor(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: kYellow));
          }
          final contractor = snap.data;
          if (contractor == null) {
            return const Center(
              child: Text('Profile not found.',
                  style: TextStyle(color: Colors.white54)),
            );
          }

          return _HubBody(contractor: contractor);
        },
      ),
    );
  }
}

// =============================================================================
// Hub Body — wraps the raw Firestore stream for compliance metadata
// =============================================================================

class _HubBody extends StatelessWidget {
  final Contractor contractor;
  const _HubBody({required this.contractor});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: FirestoreService.instance.getMyContractorDocId(),
      builder: (context, idSnap) {
        if (!idSnap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: kYellow));
        }
        final contractorId = idSnap.data!;

        // Stream the raw doc for compliance metadata (nested map not in model)
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.instance.contractors
              .doc(contractorId)
              .snapshots(),
          builder: (context, docSnap) {
            final rawData = docSnap.data?.data() ?? {};
            final complianceRaw = rawData['ComplianceDocumentsMetadata'];
            final Map<String, Map<String, dynamic>> complianceMap = {};
            if (complianceRaw is Map) {
              for (final entry in complianceRaw.entries) {
                if (entry.value is Map) {
                  complianceMap[entry.key.toString()] =
                      Map<String, dynamic>.from(entry.value as Map);
                } else if (entry.value is String &&
                    (entry.value as String).isNotEmpty) {
                  // Legacy plain URL
                  complianceMap[entry.key.toString()] = {
                    'url': entry.value,
                    'status': 'uploaded',
                  };
                }
              }
            }
            // Also check legacy top-level URL fields
            const legacyFields = {
              'profile_picture': 'SubmittedSelfieUrl',
              'ic_front': 'IcFrontUrl',
              'ic_back': 'IcBackUrl',
              'gdl_license': 'GdlLicenseUrl',
              'vehicle_grant': 'VehicleGrantUrl',
              'puspakom': 'PuspakomUrl',
            };
            for (final entry in legacyFields.entries) {
              if (!complianceMap.containsKey(entry.key)) {
                final url = rawData[entry.value]?.toString() ?? '';
                if (url.isNotEmpty) {
                  complianceMap[entry.key] = {
                    'url': url,
                    'status': 'uploaded',
                  };
                }
              }
            }

            // Show the batch submit bar when any individual document
            // (including selfie) has been uploaded/updated but the global
            // status has NOT yet been flipped to 'under_review'.
            final hasDocPending = complianceMap.values.any((meta) {
              final s = (meta['status']?.toString() ?? '').toLowerCase();
              return s == 'uploaded' || s == 'under_review';
            });
            final hasSelfiePending =
                contractor.selfieStatus.toLowerCase() == 'uploaded' ||
                contractor.selfieStatus.toLowerCase() == 'under_review';
            final hasPendingUpdates =
                (hasDocPending || hasSelfiePending) &&
                contractor.verificationStatus.toLowerCase() != 'under_review';

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      // ── Profile Section ──
                      _ProfileSection(contractor: contractor),
                      const SizedBox(height: 24),

                      // ── Compliance Documents Section ──
                      _ComplianceSection(
                        complianceMap: complianceMap,
                        verificationStatus: contractor.verificationStatus,
                        selfieStatus: contractor.selfieStatus,
                      ),
                    ],
                  ),
                ),
                if (hasPendingUpdates) const _SubmitForReviewBar(),
              ],
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Section 1 — Profile (display only)
// =============================================================================

class _ProfileSection extends StatelessWidget {
  final Contractor contractor;
  const _ProfileSection({required this.contractor});

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(contractor.fullName);
    final statusInfo = _statusInfo(contractor.verificationStatus);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: kYellow,
            backgroundImage: contractor.approvedProfileImageUrl != null &&
                    contractor.approvedProfileImageUrl!.isNotEmpty
                ? NetworkImage(contractor.approvedProfileImageUrl!)
                : null,
            child: contractor.approvedProfileImageUrl != null &&
                    contractor.approvedProfileImageUrl!.isNotEmpty
                ? null
                : Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contractor.fullName.isEmpty
                      ? 'Contractor'
                      : contractor.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contractor.email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    contractor.email,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                // Verification badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      color: statusInfo.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  _StatusDisplay _statusInfo(String status) {
    switch (status) {
      case 'approved':
        return _StatusDisplay('Verified', Colors.green);
      case 'under_review':
        return _StatusDisplay('Under Review', Colors.orange);
      case 'rejected':
        return _StatusDisplay('Requires Update', Colors.redAccent);
      default:
        return _StatusDisplay('Pending Upload', Colors.white54);
    }
  }
}

class _StatusDisplay {
  final String label;
  final Color color;
  _StatusDisplay(this.label, this.color);
}

// =============================================================================
// Section 2 — Compliance Documents (CRUD)
// =============================================================================

class _ComplianceSection extends StatelessWidget {
  final Map<String, Map<String, dynamic>> complianceMap;
  final String verificationStatus;
  final String selfieStatus;

  const _ComplianceSection({
    required this.complianceMap,
    required this.verificationStatus,
    required this.selfieStatus,
  });

  static const _docs = [
    _ComplianceDocDef(
        slug: 'profile_picture',
        label: 'Live Selfie',
        icon: Icons.face,
        isCritical: false),
    _ComplianceDocDef(
        slug: 'ic_front',
        label: 'NRIC (MyKad) Front',
        icon: Icons.badge,
        isCritical: false),
    _ComplianceDocDef(
        slug: 'ic_back',
        label: 'NRIC (MyKad) Back',
        icon: Icons.credit_card,
        isCritical: false),
    _ComplianceDocDef(
        slug: 'gdl_license',
        label: 'Driving License (GDL/Class E)',
        icon: Icons.drive_eta,
        isCritical: true,
        requiresExpiry: true),
    _ComplianceDocDef(
        slug: 'vehicle_grant',
        label: 'Vehicle Grant (VOC/Geran)',
        icon: Icons.description,
        isCritical: false,
        requiresExpiry: true),
    _ComplianceDocDef(
        slug: 'puspakom',
        label: 'PUSPAKOM Inspection Cert',
        icon: Icons.verified,
        isCritical: true,
        requiresExpiry: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.folder_shared,
          title: 'Compliance Documents',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: List.generate(_docs.length, (i) {
                final def = _docs[i];
                final meta = complianceMap[def.slug];
                final hasDoc = meta != null &&
                    (meta['url']?.toString() ?? '').isNotEmpty;

                return Column(
                  children: [
                    if (i > 0)
                      const Divider(
                          height: 1, thickness: 1, color: kBorder, indent: 62),
                    _ComplianceDocTile(
                      def: def,
                      hasDoc: hasDoc,
                      docStatus: meta?['status']?.toString() ?? '',
                      globalVerificationStatus: verificationStatus,
                      selfieStatus: selfieStatus,
                      expiry: meta?['expiry']?.toString(),
                      rejectionReason:
                          meta?['rejectionReason']?.toString() ??
                          meta?['reason']?.toString(),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComplianceDocDef {
  final String slug;
  final String label;
  final IconData icon;
  final bool isCritical; // GDL & PUSPAKOM require number + expiry
  final bool requiresExpiry; // time-sensitive documents

  const _ComplianceDocDef({
    required this.slug,
    required this.label,
    required this.icon,
    required this.isCritical,
    this.requiresExpiry = false,
  });
}

class _ComplianceDocTile extends StatelessWidget {
  final _ComplianceDocDef def;
  final bool hasDoc;
  final String docStatus; // per-document status from ComplianceDocumentsMetadata
  final String globalVerificationStatus; // contractor-level VerificationStatus
  final String selfieStatus; // dedicated SelfieStatus field for profile_picture
  final String? expiry; // ISO-8601 date string e.g. '2026-10-12'
  final String? rejectionReason;

  const _ComplianceDocTile({
    required this.def,
    required this.hasDoc,
    required this.docStatus,
    required this.globalVerificationStatus,
    required this.selfieStatus,
    this.expiry,
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final chipInfo = _chipFor();
    final expiryDisplay = _formatExpiry();
    final expired = _isExpired();

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentPreviewPage(
            documentKey: def.slug,
            documentTitle: def.label,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: chipInfo.color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(def.icon, color: chipInfo.color, size: 20),
            ),
            const SizedBox(width: 12),

            // Title + status chip + expiry
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chipInfo.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          chipInfo.label,
                          style: TextStyle(
                            color: chipInfo.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (expiryDisplay != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            expiryDisplay,
                            style: TextStyle(
                              color:
                                  expired ? Colors.redAccent : Colors.white54,
                              fontSize: 11,
                              fontWeight:
                                  expired ? FontWeight.w700 : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Rejection reason
                  if (docStatus == 'rejected' &&
                      rejectionReason != null &&
                      rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: $rejectionReason',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Chevron
            const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  String? _formatExpiry() {
    if (expiry == null || expiry!.isEmpty) return null;
    try {
      final date = DateTime.parse(expiry!);
      return 'Expires: ${DateFormat('dd MMM yyyy').format(date)}';
    } catch (_) {
      return 'Expires: $expiry';
    }
  }

  bool _isExpired() {
    if (expiry == null || expiry!.isEmpty) return false;
    try {
      final date = DateTime.parse(expiry!);
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  _StatusDisplay _chipFor() {
    if (!hasDoc) {
      return _StatusDisplay('Required', Colors.white38);
    }
    // Per-document rejection always takes priority.
    if (docStatus == 'rejected') {
      return _StatusDisplay('Rejected', Colors.redAccent);
    }
    // If the per-document status is explicitly approved, show verified.
    if (docStatus == 'approved') {
      return _StatusDisplay('Verified', Colors.green);
    }
    // Live Selfie uses its own dedicated SelfieStatus field so it is
    // not affected when a different document re-upload resets the global
    // VerificationStatus back to 'under_review'.
    if (def.slug == 'profile_picture') {
      final s = selfieStatus.toLowerCase();
      if (s == 'verified' || s == 'approved') {
        return _StatusDisplay('Verified', Colors.green);
      }
      // Fall through to the generic switch below
    } else {
      // Non-selfie documents: if the contractor's global profile is
      // approved and this document hasn't been individually rejected,
      // treat it as verified.
      if (globalVerificationStatus == 'approved') {
        return _StatusDisplay('Verified', Colors.green);
      }
    }
    switch (docStatus) {
      case 'under_review':
      case 'pending':
        return _StatusDisplay('Under Review', Colors.orange);
      default:
        return _StatusDisplay('Uploaded', Colors.orange);
    }
  }
}

// =============================================================================
// Critical Document Update Dialog (GDL / PUSPAKOM)
// =============================================================================

class _CriticalDocUpdateDialog extends StatefulWidget {
  final _ComplianceDocDef def;
  final String contractorId;

  const _CriticalDocUpdateDialog({
    required this.def,
    required this.contractorId,
  });

  @override
  State<_CriticalDocUpdateDialog> createState() =>
      _CriticalDocUpdateDialogState();
}

class _CriticalDocUpdateDialogState extends State<_CriticalDocUpdateDialog> {
  final _numberCtrl = TextEditingController();
  DateTime? _expiryDate;
  XFile? _pickedFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _retrieveLostData();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  /// Recovers a photo captured just before Android killed the app to free RAM
  /// for the native camera activity.
  Future<void> _retrieveLostData() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;
      setState(() => _pickedFile = response.file);
    } catch (e) {
      debugPrint('retrieveLostData failed: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2040),
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
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
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
            ListTile(
              leading: const Icon(Icons.camera_alt, color: kYellow),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: kYellow),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (file != null && mounted) setState(() => _pickedFile = file);
  }

  Future<void> _submit() async {
    final number = _numberCtrl.text.trim();
    if (number.isEmpty) {
      _showError('Enter the document number.');
      return;
    }
    if (_expiryDate == null) {
      _showError('Select an expiry date.');
      return;
    }
    if (_pickedFile == null) {
      _showError('Capture or select a document image.');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Upload image
      final url = await StorageService.instance.uploadVerificationDoc(
        contractorId: widget.contractorId,
        docKey: widget.def.slug,
        file: _pickedFile!,
      );

      // Update the nested compliance metadata for this doc
      final expiryStr =
          '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}';

      // Use field-level dot-notation so only the targeted document key
      // is modified — other sibling entries are untouched.
      final prefix = 'ComplianceDocumentsMetadata.${widget.def.slug}';
      await FirestoreService.instance.updateContractorProfile({
        '$prefix.url': url,
        '$prefix.status': 'under_review',
        '$prefix.expiry': expiryStr,
        '$prefix.docNumber': number,
        // NOTE: VerificationStatus is NOT flipped here. The contractor
        // must tap "Submit Updates for Review" to batch-notify the admin.
        'LastSubmittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document submitted for review.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update ${widget.def.label}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Provide updated document details for admin review.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Document number
              TextField(
                controller: _numberCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Document / License Number'),
              ),
              const SizedBox(height: 14),

              // Expiry date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: Colors.white38),
                      const SizedBox(width: 10),
                      Text(
                        _expiryDate != null
                            ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                            : 'Select Expiry Date',
                        style: TextStyle(
                          color: _expiryDate != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Image picker
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickImage,
                icon: Icon(
                  _pickedFile != null ? Icons.check_circle : Icons.camera_alt,
                  size: 18,
                ),
                label: Text(
                    _pickedFile != null ? 'Image Selected' : 'Capture Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _pickedFile != null ? Colors.green : kYellow,
                  side: BorderSide(
                    color: _pickedFile != null
                        ? Colors.green.withAlpha(150)
                        : kBorder,
                  ),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: kYellow.withAlpha(80),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text('Submit for Review',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kYellow, width: 1.5),
        ),
      );
}

// =============================================================================
// Batch submit bar — one-tap to notify admin of all pending updates
// =============================================================================

class _SubmitForReviewBar extends StatefulWidget {
  const _SubmitForReviewBar();

  @override
  State<_SubmitForReviewBar> createState() => _SubmitForReviewBarState();
}

class _SubmitForReviewBarState extends State<_SubmitForReviewBar> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await FirestoreService.instance.updateContractorProfile({
        'VerificationStatus': 'under_review',
        'LastSubmittedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updates submitted to Admin for review'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: kCard,
        border: const Border(top: BorderSide(color: kBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black),
                  )
                : const Icon(Icons.send, size: 20),
            label: Text(
              _submitting ? 'Submitting...' : 'Submit Updates for Review',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
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

// =============================================================================
// Shared widgets
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kYellow, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
