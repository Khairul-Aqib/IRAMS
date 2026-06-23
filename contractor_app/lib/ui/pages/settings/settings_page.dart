import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../models/contractor.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../widgets/app_loader.dart';
import '../profile/change_password_page.dart' show ChangePasswordPage;

/// Premium Settings page wired to real Firebase logic.
///
/// - Notifications toggle persists to `Contractor/{docId}.NotificationsEnabled`
///   via [FirestoreService.setNotificationsEnabled] and reads back via the
///   same stream the rest of the app uses ([FirestoreService.watchMyContractor]).
/// - Delete Account uses [AuthService.deleteAccount] which performs a
///   soft delete (sets `IsDeleted` / `AccountStatus` in Firestore) and
///   signs the user out.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdatingNotifications = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: kCard,
      ),
      body: StreamBuilder<Contractor?>(
        stream: FirestoreService.instance.watchMyContractor(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const AppLoader();
          }

          final contractor = snap.data;
          final user = FirebaseAuth.instance.currentUser;

          return ListView(
            // Bottom padding clears the floating pill bottom-nav (≈80px) plus
            // breathing room so the Danger Zone is never covered.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // ── ACCOUNT ──────────────────────────────────────────────
              const _SectionLabel('Account'),
              const SizedBox(height: 8),
              _SettingsGroup(
                tiles: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    iconColor: kYellow,
                    title: 'Account Information',
                    subtitle: user?.email ?? 'Not signed in',
                    onTap: () => _showAccountInfo(context, user, contractor),
                  ),
                  if (_isPasswordUser(user))
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      iconColor: Colors.lightBlueAccent,
                      title: 'Change Password',
                      subtitle: 'Update your sign-in password',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordPage(),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // ── PREFERENCES ──────────────────────────────────────────
              const _SectionLabel('Preferences'),
              const SizedBox(height: 8),
              _SettingsGroup(
                tiles: [
                  _NotificationToggleTile(
                    enabled: contractor?.notificationsEnabled ?? true,
                    isUpdating: _isUpdatingNotifications,
                    onChanged: (value) =>
                        _onToggleNotifications(value, contractor),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── ABOUT ────────────────────────────────────────────────
              const _SectionLabel('About'),
              const SizedBox(height: 8),
              _SettingsGroup(
                tiles: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    iconColor: Colors.tealAccent,
                    title: 'About IRAMS',
                    subtitle: 'Version ${MiscConstants.appVersion}',
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── DANGER ZONE ──────────────────────────────────────────
              const _SectionLabel('Danger Zone', color: Colors.redAccent),
              const SizedBox(height: 8),
              _DangerZone(
                isDeleting: _isDeleting,
                onDelete: () => _onDeleteAccount(context),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Notifications toggle ─────────────────────────────────────────────────

  Future<void> _onToggleNotifications(
    bool value,
    Contractor? contractor,
  ) async {
    if (_isUpdatingNotifications) return;
    if (contractor == null) {
      _showError('Profile not loaded yet. Please try again.');
      return;
    }

    setState(() => _isUpdatingNotifications = true);
    try {
      await FirestoreService.instance.setNotificationsEnabled(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Notifications enabled'
                  : 'Notifications disabled',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to update notifications preference: $e');
      _showError('Could not update notification preference. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdatingNotifications = false);
    }
  }

  // ── Delete account ───────────────────────────────────────────────────────

  Future<void> _onDeleteAccount(BuildContext context) async {
    if (_isDeleting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You are not signed in.');
      return;
    }

    // Step 1 — hard confirmation dialog: user must type DELETE to proceed.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var confirmText = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isConfirmed = confirmText == 'DELETE';
            return AlertDialog(
              backgroundColor: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Delete account?'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent and cannot be undone.\n\n'
                    'Your contractor profile, job history, and earnings records '
                    'will be lost. You will no longer receive job requests.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Type DELETE to confirm:',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setDialogState(() => confirmText = v),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        letterSpacing: 2,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isConfirmed
                              ? Colors.redAccent
                              : kBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isConfirmed
                              ? Colors.redAccent
                              : kBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isConfirmed
                              ? Colors.redAccent
                              : kYellow,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isConfirmed
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.withAlpha(60),
                    disabledForegroundColor: Colors.white38,
                  ),
                  child: const Text('Delete forever'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    // Step 2 — perform the soft deletion.
    setState(() => _isDeleting = true);
    try {
      await AuthService.instance.deleteAccount();
      if (!context.mounted) return;
      // Auth state change will redirect via GoRouter, but call go() explicitly
      // for the snappy transition the user expects.
      context.go('/login');
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      if (mounted) _showError('Could not delete account. Please try again.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool _isPasswordUser(User? user) =>
      user?.providerData.any((p) => p.providerId == 'password') ?? false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade900,
      ),
    );
  }

  void _showAccountInfo(
    BuildContext context,
    User? user,
    Contractor? contractor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 20),
            const Text(
              'Account Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _InfoRow(
              label: 'Full Name',
              value: contractor?.fullName ?? 'N/A',
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Phone Number',
              value: (contractor != null && contractor.phone.isNotEmpty)
                  ? contractor.phone
                  : 'N/A',
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Email', value: user?.email ?? 'N/A'),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                final uid = user?.uid ?? '';
                if (uid.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: uid));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Support ID copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Support ID',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.uid ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Colors.white30,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SheetHandle(),
            SizedBox(height: 20),
            Text(
              MiscConstants.appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version ${MiscConstants.appVersion}',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              'Intelligent Roadside Assistance Management System',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              '© 2026 IRAMS. All rights reserved.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {this.color = Colors.white54});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Grouped settings container ────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> tiles;
  const _SettingsGroup({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i != tiles.length - 1) {
        children.add(const Divider(
          height: 1,
          thickness: 1,
          indent: 60,
          color: kBorder,
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: children),
      ),
    );
  }
}

// ── Standard tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
        size: 22,
      ),
    );
  }
}

// ── Notification toggle tile ──────────────────────────────────────────────────

class _NotificationToggleTile extends StatelessWidget {
  final bool enabled;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleTile({
    required this.enabled,
    required this.isUpdating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: enabled,
      onChanged: isUpdating ? null : onChanged,
      activeColor: kYellow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isUpdating
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orangeAccent,
                  ),
                ),
              )
            : const Icon(
                Icons.notifications_outlined,
                color: Colors.orangeAccent,
                size: 20,
              ),
      ),
      title: const Text(
        'Push Notifications',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        enabled
            ? 'Receive new job request alerts'
            : 'New job alerts are paused',
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

// ── Danger zone block ─────────────────────────────────────────────────────────

class _DangerZone extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onDelete;

  const _DangerZone({
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withAlpha(80)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Permanently remove your contractor account and all associated data. This cannot be undone.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever, size: 20),
                  label: Text(
                    isDeleting ? 'Deleting…' : 'Delete My Account',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.withAlpha(120),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

// ── Bottom sheet drag handle ──────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Account info row ──────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}
