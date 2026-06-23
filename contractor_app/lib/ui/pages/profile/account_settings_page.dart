import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../core/theme.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  Future<void> _showDeactivateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: kBorder),
              ),
              title: const Text('Deactivate Account?'),
              content: const Text(
                'Your account will be suspended. You can contact support to reactivate it.',
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setDialogState(() => loading = true);
                          try {
                            await AuthService.instance.deactivateAccount();
                            // GoRouter auto-redirects to /login after logout
                          } catch (e) {
                            if (ctx.mounted) {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(ctx).pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Deactivate',
                          style: TextStyle(color: Colors.orange),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: kBorder),
              ),
              title: const Text('Deactivate Account'),
              content: const Text(
                'Are you sure? You will lose access to IRAMS and must '
                'contact the Admin to reactivate your account. Your past '
                'job history will be retained for accounting purposes.',
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setDialogState(() => loading = true);
                          try {
                            await AuthService.instance.deleteAccount();
                            // GoRouter auto-redirects to /login after logout
                          } catch (e) {
                            if (ctx.mounted) {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(ctx).pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Deactivate',
                          style: TextStyle(color: Colors.red),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('Account Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Deactivate section ──────────────────────────────────────────────
          Card(
            color: kCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pause_circle_outline,
                          color: Colors.orange, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Deactivate Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Temporarily suspend your account. This is reversible — '
                    'contact support to reactivate your account at any time.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showDeactivateDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Deactivate Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Delete (soft) section ────────────────────────────────────────────
          Card(
            color: kCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.delete_forever_outlined,
                          color: Colors.red, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Deactivate your account and lose access to IRAMS. '
                    'Your job history is retained for accounting. '
                    'Contact Admin to reactivate.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showDeleteDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Delete Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

