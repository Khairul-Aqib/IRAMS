import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../core/theme.dart';
import '../../widgets/app_loader.dart';

// ── Document slot model ────────────────────────────────────────────────────────

class _DocSlot {
  final String label;
  final String description;
  final IconData icon;
  final String firestoreField; // URL field on the Contractor doc
  final String storageKey;     // Filename used in Firebase Storage

  String? existingUrl; // Previously uploaded (from Firestore)
  XFile? newFile;      // Newly selected (not yet uploaded)

  _DocSlot({
    required this.label,
    required this.description,
    required this.icon,
    required this.firestoreField,
    required this.storageKey,
  });

  /// True if this slot has content — either an existing upload or a new selection.
  bool get hasContent => newFile != null || existingUrl != null;
}

// ── Page ───────────────────────────────────────────────────────────────────────

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _picker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  String _currentStatus = 'Pending';

  late final List<_DocSlot> _slots = [
    _DocSlot(
      label: 'Driving Licence',
      description: 'Valid government-issued driver\'s licence',
      icon: Icons.credit_card,
      firestoreField: 'DrivingLicenceUrl',
      storageKey: 'driving_licence',
    ),
    _DocSlot(
      label: 'Vehicle Registration',
      description: 'Current vehicle registration certificate',
      icon: Icons.directions_car,
      firestoreField: 'VehicleRegistrationUrl',
      storageKey: 'vehicle_registration',
    ),
    _DocSlot(
      label: 'Business Registration',
      description: 'Business registration / operating permits',
      icon: Icons.business,
      firestoreField: 'BusinessRegistrationUrl',
      storageKey: 'business_registration',
    ),
    _DocSlot(
      label: 'Proof of Insurance',
      description: 'Valid vehicle or business insurance policy',
      icon: Icons.shield,
      firestoreField: 'ProofOfInsuranceUrl',
      storageKey: 'proof_of_insurance',
    ),
  ];

  bool get _allComplete => _slots.every((s) => s.hasContent);

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
        _currentStatus = (d['VerificationStatus'] ?? 'pending_upload').toString();
        for (final slot in _slots) {
          slot.existingUrl = d[slot.firestoreField]?.toString();
        }
      }
    } catch (_) {
      // Non-fatal — proceed with empty slots
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(_DocSlot slot) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => slot.newFile = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open gallery: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_allComplete || _submitting) return;

    setState(() => _submitting = true);
    try {
      final contractorId =
          await FirestoreService.instance.getMyContractorDocId();
      if (contractorId == null) throw Exception('Contractor not found');

      // Upload all newly selected files concurrently
      final updates = <String, dynamic>{};
      await Future.wait(_slots.map((slot) async {
        if (slot.newFile != null) {
          final url = await StorageService.instance.uploadVerificationDoc(
            contractorId: contractorId,
            docKey: slot.storageKey,
            file: slot.newFile!,
          );
          updates[slot.firestoreField] = url;
        } else if (slot.existingUrl != null) {
          // Keep the previously uploaded URL unchanged
          updates[slot.firestoreField] = slot.existingUrl;
        }
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
                Text('Documents submitted for admin review'),
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: const Text(
          'Verification Documents',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const AppLoader()
          : _buildBody(),
      bottomNavigationBar: _loading ? null : _buildSubmitBar(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusBanner(),
        const SizedBox(height: 20),
        _buildIntroCard(),
        const SizedBox(height: 20),
        ..._slots.map((slot) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDocCard(slot),
            )),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatusBanner() {
    Color color;
    IconData icon;
    String message;

    switch (_currentStatus.toLowerCase()) {
      case 'verified':
        color = Colors.green;
        icon = Icons.verified;
        message = 'Your account is Verified. You can receive jobs.';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        message = 'Verification was rejected. Please re-upload your documents.';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
        message = 'Awaiting admin review. This usually takes 1–2 business days.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          Text(
            'Required Documents',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Upload all 4 documents below to request account verification. Your account must be Verified before you can receive job requests.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(_DocSlot slot) {
    final isComplete = slot.hasContent;
    final hasNew = slot.newFile != null;

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? Colors.green.withOpacity(0.5) : kBorder,
          width: isComplete ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green.withOpacity(0.12)
                        : kYellow.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    slot.icon,
                    color: isComplete ? Colors.green : kYellow,
                    size: 20,
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
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),

          // Image preview
          if (hasNew)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.file(
                File(slot.newFile!.path),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (slot.existingUrl != null)
            Stack(
              children: [
                Image.network(
                  slot.existingUrl!,
                  height: 160,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // Select button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickImage(slot),
                icon: Icon(
                  hasNew ? Icons.swap_horiz : Icons.upload_file,
                  size: 18,
                ),
                label: Text(
                  hasNew
                      ? 'Change Selection'
                      : slot.existingUrl != null
                          ? 'Replace Document'
                          : 'Select Document',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kYellow,
                  side: BorderSide(color: kYellow.withOpacity(0.6)),
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
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    final completedCount = _slots.where((s) => s.hasContent).length;
    final allDone = completedCount == _slots.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: kCard,
        border: const Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!allDone)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$completedCount / ${_slots.length} documents selected',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (allDone && !_submitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: kYellow.withOpacity(0.25),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: _submitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading documents...',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : const Text(
                        'Submit for Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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
