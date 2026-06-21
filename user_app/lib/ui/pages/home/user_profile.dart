import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/services/user_firestore_service.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _profileLinkMissing = false;

  String _customUserId = '';
  String? _profileImageUrl;

  // Account-lifecycle fields displayed under the user-id badge.
  // Falls back to legacy `CreatedAt` when `registrationDate` is missing on
  // pre-existing accounts that registered before the field was introduced.
  DateTime? _registrationDate;
  String _accountStatus = '';

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load profile from Firestore
  // ---------------------------------------------------------------------------

  Future<void> _loadUserData() async {
    if (user == null) return;

    try {
      // Resolve the linked U*** doc by querying authUid.
      final customId = await UserFirestoreService.instance.getCustomUserId();
      if (customId.isEmpty) {
        _profileLinkMissing = true;
      } else {
        _customUserId = customId;
        final doc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(customId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          _email.text = data['email'] ?? user!.email ?? '';
          _firstName.text = data['firstName'] ?? '';
          _lastName.text = data['lastName'] ?? '';
          _phone.text = data['phone'] ?? '';
          _profileImageUrl = data['profileImageUrl'] as String?;

          // Prefer the new `registrationDate`; fall back to legacy `CreatedAt`
          // so accounts created before this refactor still render a join date.
          final regTs = data['registrationDate'] ?? data['CreatedAt'];
          if (regTs is Timestamp) _registrationDate = regTs.toDate();

          // Tolerate either casing on read so legacy accounts that were
          // created when this was 'status' still render the badge correctly.
          final rawStatus = (data['Status'] ?? data['status']) as String?;
          _accountStatus = rawStatus?.trim() ?? '';
        } else {
          // The lookup pointed to an id that has since been deleted.
          _profileLinkMissing = true;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  // ---------------------------------------------------------------------------
  // Save profile to Firestore
  // ---------------------------------------------------------------------------

  Future<void> _saveProfile() async {
    if (user == null) return;

    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final phone = _phone.text.trim();
    final fullName = '$firstName $lastName'.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnack('Please enter your first and last name.', Colors.redAccent);
      return;
    }

    if (_customUserId.isEmpty) {
      _showSnack(
        'No linked profile (U***) found for this account. '
        'Ask an admin to link your auth UID in the Users collection.',
        Colors.redAccent,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_customUserId)
          .set({
        'authUid': user!.uid,
        'email': _email.text.trim(),
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'fullName': fullName,
      }, SetOptions(merge: true));

      // Keep Auth displayName in sync
      await user!.updateDisplayName(fullName);

      if (!mounted) return;
      _showSnack('Profile updated successfully', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save profile. Please try again.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Change password — reauthenticate with old password, then update
  // ---------------------------------------------------------------------------

  Future<void> _changePassword() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (success == true && mounted) {
      _showSnack('Password Updated Successfully', Colors.green);
    }
  }

  // ---------------------------------------------------------------------------
  // Change profile photo — pick, compress, upload to Storage, write URL
  // ---------------------------------------------------------------------------

  void _changeProfilePhoto() {
    if (_uploadingImage) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                uploadProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                uploadProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> uploadProfileImage(ImageSource source) async {
    if (user == null || _uploadingImage) return;

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        // Compress to keep Storage costs and upload time low.
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (e) {
      _showSnack('Could not open $source: $e', Colors.redAccent);
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingImage = true);

    try {
      final uid = user!.uid;
      final ref =
          FirebaseStorage.instance.ref().child('profile_pictures/$uid.jpg');

      await ref.putFile(
        File(picked.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      if (_customUserId.isEmpty) {
        _showSnack(
          'No linked profile (U***) found — cannot save photo.',
          Colors.redAccent,
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_customUserId)
          .set(
        {'profileImageUrl': url},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _profileImageUrl = url);
      _showSnack('Profile photo updated', Colors.green);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showSnack('Upload failed: ${e.message ?? e.code}', Colors.redAccent);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Upload failed: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showSnack(String msg, Color bg) {
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
      drawer: const AppDrawer(),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : _profileLinkMissing
                ? _buildLinkMissing()
                : Column(
                children: [
                  // TOP BAR
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu,
                                color: Colors.white),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // AVATAR
                  GestureDetector(
                    onTap: _changeProfilePhoto,
                    child: Column(
                      children: [
                        _buildAvatar(),
                        const SizedBox(height: 8),
                        const Text(
                          'Change Photo',
                          style:
                              TextStyle(color: Colors.amber, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // USER ID BADGE
                  if (_customUserId.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          'ID: $_customUserId',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ACCOUNT LIFECYCLE — "Member since" + Status badge
                  _buildLifecycleRow(),

                  const SizedBox(height: 16),

                  // FORM
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _inputField(
                            label: 'Email',
                            icon: Icons.email,
                            controller: _email,
                            enabled: false,
                          ),
                          const SizedBox(height: 14),

                          _inputField(
                            label: 'First Name',
                            icon: Icons.person,
                            controller: _firstName,
                          ),
                          const SizedBox(height: 14),

                          _inputField(
                            label: 'Last Name',
                            icon: Icons.person_outline,
                            controller: _lastName,
                          ),
                          const SizedBox(height: 14),

                          _inputField(
                            label: 'Phone Number',
                            icon: Icons.phone,
                            controller: _phone,
                          ),

                          const SizedBox(height: 24),

                          // SAVE BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _saving ? null : _saveProfile,
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Save Profile',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // CHANGE PASSWORD
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Colors.amber),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _changePassword,
                              child: const Text(
                                'Change Password',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLinkMissing() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link_off, color: Colors.orangeAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No Profile Linked',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No document in the Users collection has '
            'authUid = "${user?.uid ?? ''}".\n\n'
            'Open Firebase Console → Users, find your U*** doc, and set the '
            '"authUid" field to the value above. Then reopen this screen.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Renders "Member since: Mon Year" alongside a coloured Status pill.
  /// Hidden entirely if both fields are missing (legacy doc with no audit
  /// data) so the layout doesn't show an empty placeholder row.
  Widget _buildLifecycleRow() {
    final hasDate = _registrationDate != null;
    final hasStatus = _accountStatus.isNotEmpty;
    if (!hasDate && !hasStatus) return const SizedBox.shrink();

    final memberSince = hasDate
        ? 'Member since: ${DateFormat('MMM yyyy').format(_registrationDate!)}'
        : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasDate)
          Text(
            memberSince,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        if (hasDate && hasStatus) const SizedBox(width: 10),
        if (hasStatus) _StatusBadge(status: _accountStatus),
      ],
    );
  }

  Widget _buildAvatar() {
    const double radius = 40;
    const double diameter = radius * 2;

    Widget inner;
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      inner = ClipOval(
        child: CachedNetworkImage(
          imageUrl: _profileImageUrl!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.amber,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          ),
          errorWidget: (_, __, ___) => const CircleAvatar(
            radius: radius,
            backgroundColor: Colors.amber,
            child: Icon(Icons.person, size: 42, color: Colors.black),
          ),
        ),
      );
    } else {
      inner = const CircleAvatar(
        radius: radius,
        backgroundColor: Colors.amber,
        child: Icon(Icons.person, size: 42, color: Colors.black),
      );
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: inner),
          if (_uploadingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.amber,
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber,
                border: Border.all(color: const Color(0xFF121212), width: 2),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.camera_alt,
                  size: 14, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(border: InputBorder.none),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Change Password dialog — reauthenticates with the old password before
// calling updatePassword. Pops with `true` on success, `false` on cancel.
// =============================================================================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _oldHidden = true;
  bool _newHidden = true;
  bool _confirmHidden = true;

  bool _loading = false;
  String? _inlineError;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final oldPw = _old.text;
    final newPw = _new.text;
    final confirmPw = _confirm.text;

    if (oldPw.isEmpty) {
      setState(() => _inlineError = 'Please enter your current password.');
      return;
    }
    if (newPw.length < 6) {
      setState(
          () => _inlineError = 'New password must be at least 6 characters.');
      return;
    }
    if (newPw != confirmPw) {
      setState(() =>
          _inlineError = 'New password and confirmation do not match.');
      return;
    }
    if (newPw == oldPw) {
      setState(() =>
          _inlineError = 'New password must differ from the old password.');
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    final email = authUser?.email ?? '';
    if (authUser == null || email.isEmpty) {
      setState(() => _inlineError = 'Not signed in.');
      return;
    }

    setState(() {
      _loading = true;
      _inlineError = null;
    });

    try {
      final cred =
          EmailAuthProvider.credential(email: email, password: oldPw);
      await authUser.reauthenticateWithCredential(cred);
      await authUser.updatePassword(newPw);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      final messenger = ScaffoldMessenger.of(context);
      switch (e.code) {
        // Firebase returns one of these when the old password is wrong,
        // depending on whether Identity Platform is enabled on the project.
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          messenger.showSnackBar(const SnackBar(
            content: Text('The old password you entered is incorrect.'),
            backgroundColor: Colors.redAccent,
          ));
          break;
        case 'weak-password':
          messenger.showSnackBar(const SnackBar(
            content:
                Text('That new password is too weak. Try a stronger one.'),
            backgroundColor: Colors.redAccent,
          ));
          break;
        case 'too-many-requests':
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Too many attempts. Please wait a moment and try again.'),
            backgroundColor: Colors.orangeAccent,
          ));
          break;
        case 'requires-recent-login':
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Session expired. Please log out and back in, then try again.'),
            backgroundColor: Colors.orangeAccent,
          ));
          break;
        case 'network-request-failed':
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Network error. Check your connection and try again.'),
            backgroundColor: Colors.redAccent,
          ));
          break;
        default:
          messenger.showSnackBar(SnackBar(
            content: Text('Error: ${e.message ?? e.code}'),
            backgroundColor: Colors.redAccent,
          ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update password: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Change Password',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              controller: _old,
              hint: 'Old Password',
              hidden: _oldHidden,
              onToggle: () => setState(() => _oldHidden = !_oldHidden),
              autofill: const [AutofillHints.password],
            ),
            const SizedBox(height: 12),
            _field(
              controller: _new,
              hint: 'New Password (min 6 characters)',
              hidden: _newHidden,
              onToggle: () => setState(() => _newHidden = !_newHidden),
              autofill: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 12),
            _field(
              controller: _confirm,
              hint: 'Confirm New Password',
              hidden: _confirmHidden,
              onToggle:
                  () => setState(() => _confirmHidden = !_confirmHidden),
              autofill: const [AutofillHints.newPassword],
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 14),
              Text(
                _inlineError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amber,
                  ),
                )
              : const Text(
                  'Update',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool hidden,
    required VoidCallback onToggle,
    required List<String> autofill,
  }) {
    return TextField(
      controller: controller,
      obscureText: hidden,
      autofillHints: autofill,
      enabled: !_loading,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.amber),
        ),
        disabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white12),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            hidden ? Icons.visibility_off : Icons.visibility,
            color: Colors.white54,
            size: 20,
          ),
          onPressed: _loading ? null : onToggle,
        ),
      ),
    );
  }
}

// =============================================================================
// Status badge — coloured pill that reflects the Users.status field. Green for
// 'Active', red for 'Suspended', grey for anything else (incl. unknown values
// the Admin Portal might introduce later).
// =============================================================================

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final Color bg;
    switch (s) {
      case 'active':
        bg = const Color(0xFF2E7D32); // green 800
        break;
      case 'suspended':
      case 'banned':
        bg = const Color(0xFFC62828); // red 800
        break;
      default:
        bg = const Color(0xFF616161); // grey 700
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
