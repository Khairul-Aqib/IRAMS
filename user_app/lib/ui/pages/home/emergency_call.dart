import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:user_app/constants/colors.dart';
import 'package:user_app/services/user_firestore_service.dart';

/// Screen that doubles as an editor for the user's emergency contact and a
/// one-tap dialer. Loads `emergencyContactName` / `emergencyContactPhone` from
/// `Users/{U***}` on open, lets the user edit and save them, and dials the
/// number currently in the controller (not a hard-coded fallback).
class EmergencyCallPage extends StatefulWidget {
  const EmergencyCallPage({super.key});

  @override
  State<EmergencyCallPage> createState() => _EmergencyCallPageState();
}

class _EmergencyCallPageState extends State<EmergencyCallPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _profileMissing = false;
  String _customUserId = '';

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load current values from Users/{U***}
  // ---------------------------------------------------------------------------

  Future<void> _loadEmergencyContact() async {
    try {
      final customId = await UserFirestoreService.instance.getCustomUserId();
      if (customId.isEmpty) {
        if (mounted) {
          setState(() {
            _profileMissing = true;
            _loading = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(customId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _profileMissing = true;
            _loading = false;
          });
        }
        return;
      }

      final data = doc.data() ?? {};
      nameController.text = (data['emergencyContactName'] ?? '').toString();
      phoneController.text = (data['emergencyContactPhone'] ?? '').toString();

      if (mounted) {
        setState(() {
          _customUserId = customId;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not load emergency contact: $e', Colors.redAccent);
    }
  }

  // ---------------------------------------------------------------------------
  // Save the controllers' current values back to Firestore
  // ---------------------------------------------------------------------------

  Future<void> _saveContact() async {
    if (_customUserId.isEmpty) {
      _snack('No linked profile found.', Colors.redAccent);
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_customUserId)
          .update({
        'emergencyContactName': nameController.text.trim(),
        'emergencyContactPhone': phoneController.text.trim(),
      });

      if (!mounted) return;
      _snack('Emergency contact saved', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to save: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Dial whatever is in the phone field right now (no hard-coded fallback)
  // ---------------------------------------------------------------------------

  Future<void> _callEmergency() async {
    // Strip every whitespace character anywhere inside the number — handles
    // typed values like "+60 12-345 6789" or pasted ones with stray gaps.
    final cleaned = phoneController.text
        .trim()
        .replaceAll(RegExp(r'\s+\b|\b\s'), '');

    if (cleaned.isEmpty) {
      _snack(
        'Please enter an emergency phone number first.',
        Colors.redAccent,
      );
      return;
    }

    final telUrl = 'tel:$cleaned';
    final uri = Uri.parse(telUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // canLaunchUrl returned false — typically a missing AndroidManifest
        // <queries> entry for `tel`, no SIM/dialer, or a malformed URI.
        // Echo the exact string so the cause is visible in flutter run logs.
        debugPrint('[EmergencyCall] canLaunchUrl rejected: "$telUrl"');
        if (mounted) {
          _snack('Could not launch dialer for $cleaned', Colors.redAccent);
        }
      }
    } catch (e, st) {
      // Plugin / platform-channel failure (rare). Print the URL alongside
      // the exception so we can correlate logs.
      debugPrint('[EmergencyCall] launchUrl threw on "$telUrl": $e\n$st');
      if (mounted) {
        _snack('Failed to open dialer: $e', Colors.redAccent);
      }
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EMERGENCY CALL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kYellow))
          : _profileMissing
              ? _buildProfileMissing()
              : _buildBody(),
    );
  }

  Widget _buildProfileMissing() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No linked profile found.\nYour emergency contact cannot be loaded.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section 1: Contact settings card ──────────────────────────
          _SettingsCard(
            nameController: nameController,
            phoneController: phoneController,
            saving: _saving,
            onSave: _saveContact,
          ),

          // ── Section break ─────────────────────────────────────────────
          const SizedBox(height: 32),
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 36),

          // ── Section 2: Emergency dialer ───────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 56,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Emergency Assistance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Use this option only for urgent situations.\n'
                  'We will dial the number above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Hero call button ──
              _HeroCallButton(onPressed: _callEmergency),

              const SizedBox(height: 14),

              // Live preview of what will be dialled.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: phoneController,
                builder: (context, value, _) {
                  final txt = value.text.trim();
                  return Text(
                    txt.isEmpty ? 'No number set' : 'Will dial: $txt',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Settings card — groups the two TextFormFields with a compact "Save" action
// in the top-right corner so the configuration reads as a single unit and
// doesn't compete with the red emergency button.
// =============================================================================

class _SettingsCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool saving;
  final VoidCallback onSave;

  const _SettingsCard({
    required this.nameController,
    required this.phoneController,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header — title on the left, compact Save action on the right.
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Contact Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              _SaveAction(saving: saving, onPressed: onSave),
            ],
          ),

          const SizedBox(height: 16),

          _FieldGroup(
            label: 'Name',
            child: TextFormField(
              controller: nameController,
              keyboardType: TextInputType.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: _fieldDecoration('e.g. Aisyah'),
            ),
          ),

          const SizedBox(height: 14),

          _FieldGroup(
            label: 'Phone Number',
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              decoration: _fieldDecoration('+60 12-345 6789'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white12),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: kYellow, width: 1.5),
      ),
    );
  }
}

/// Small label + child column. The label is intentionally small and muted so
/// the actual input value reads as the primary content.
class _FieldGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

/// Compact save action that sits in the card header. Outlined while idle,
/// shows a tiny inline spinner during the save so the user knows something
/// is happening without a full-width loading state taking over the card.
class _SaveAction extends StatelessWidget {
  final bool saving;
  final VoidCallback onPressed;

  const _SaveAction({required this.saving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: saving ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: kYellow,
        disabledForegroundColor: kYellow.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: saving
                ? kYellow.withValues(alpha: 0.3)
                : kYellow.withValues(alpha: 0.6),
          ),
        ),
      ),
      icon: saving
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: kYellow),
            )
          : const Icon(Icons.check, size: 14),
      label: Text(
        saving ? 'Saving' : 'Save',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// =============================================================================
// Hero call button — the screen's primary action. Refined 12 px radius and a
// soft red glow so it reads as a tactile "press me in a crisis" target.
// =============================================================================

class _HeroCallButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HeroCallButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          icon: const Icon(Icons.phone, color: Colors.white, size: 20),
          label: const Text(
            'CALL EMERGENCY',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
