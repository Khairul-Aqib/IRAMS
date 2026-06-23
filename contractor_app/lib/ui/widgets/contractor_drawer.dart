import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/contractor.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../core/theme.dart';
import '../pages/profile/document_status_page.dart';
import '../pages/profile/earnings_page.dart';
import '../pages/profile/wallet_page.dart';
import '../pages/chat/support_chat_page.dart';
import '../pages/settings/settings_page.dart';

class ContractorDrawer extends StatelessWidget {
  /// Called when the user taps "Home / Map" — the shell should switch to
  /// the given tab index (0 = Jobs, 1 = Map).
  final void Function(int tabIndex)? onTabSelected;

  const ContractorDrawer({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kBg,
      child: StreamBuilder<Contractor?>(
        stream: FirestoreService.instance.watchMyContractor(),
        builder: (context, snap) {
          final contractor = snap.data;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Header ──
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: kCard),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: kYellow,
                  backgroundImage: contractor?.approvedProfileImageUrl !=
                              null &&
                          contractor!.approvedProfileImageUrl!.isNotEmpty
                      ? NetworkImage(contractor.approvedProfileImageUrl!)
                      : null,
                  child: contractor?.approvedProfileImageUrl != null &&
                          contractor!.approvedProfileImageUrl!.isNotEmpty
                      ? null
                      : Text(
                          _initials(contractor?.fullName ?? ''),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                accountName: Text(
                  contractor?.fullName ?? 'Contractor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                accountEmail: Text(
                  contractor?.email ?? '',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),

              // ── Navigation items ──
              _DrawerTile(
                icon: Icons.work_outline,
                label: 'Jobs',
                onTap: () {
                  Navigator.pop(context);
                  onTabSelected?.call(0);
                },
              ),
              _DrawerTile(
                icon: Icons.map_outlined,
                label: 'Map',
                onTap: () {
                  Navigator.pop(context);
                  onTabSelected?.call(1);
                },
              ),
              _DrawerTile(
                icon: Icons.payments_outlined,
                label: 'Earnings & History',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EarningsPage()),
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'My Wallet',
                trailing: contractor != null
                    ? Text(
                        'RM ${contractor.walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kYellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletPage()),
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.verified_user,
                label: 'Compliance Documents',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DocumentStatusPage()),
                  );
                },
              ),
              const Divider(color: kBorder),
              _DrawerTile(
                icon: Icons.support_agent,
                label: 'Help & Support',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SupportChatPage()),
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.logout,
                label: 'Logout',
                color: Colors.red,
                onTap: () => _handleLogout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Close drawer first
    Navigator.pop(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthService.instance.logout();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 12,
    );
  }
}
