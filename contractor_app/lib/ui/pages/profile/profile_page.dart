import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/contractor.dart';
import '../../../models/job.dart';
import '../../../models/review.dart';
import '../../../core/theme.dart';
import '../../widgets/app_loader.dart';
import 'earnings_page.dart';
import 'reviews_page.dart';
import 'contractor_profile.dart';
import 'document_upload_page.dart';
import 'document_status_page.dart';
import 'wallet_page.dart';
import '../settings/settings_page.dart';
import '../chat/support_chat_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contractor?>(
      stream: FirestoreService.instance.watchMyContractor(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        final c = snap.data;
        if (c == null) {
          return const Center(
            child: Text('Profile not found. Register again or create contractor doc.'),
          );
        }

        return ListView(
          // Bottom padding clears the floating pill bottom-nav (≈80px) plus
          // breathing room so the Logout button is never covered.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            _VerificationBanner(status: c.verificationStatus),
            const SizedBox(height: 16),

            // ── Premium hero header ───────────────────────────────────────
            _ProfileHeader(contractor: c),
            const SizedBox(height: 24),

            // ── Section: Account ──────────────────────────────────────────
            const _SectionLabel('Account'),
            const SizedBox(height: 8),
            _SettingsGroup(
              tiles: [
                _SettingsTile(
                  icon: Icons.edit_outlined,
                  iconColor: kYellow,
                  title: 'Edit Profile',
                  subtitle: 'Update contact details and services',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ContractorProfileEditPage(),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: Colors.greenAccent,
                  title: 'My Wallet',
                  subtitle: 'Balance, top-up and withdrawals',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WalletPage(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section: Activity ─────────────────────────────────────────
            const _SectionLabel('Activity'),
            const SizedBox(height: 8),
            _SettingsGroup(
              tiles: [
                _SettingsTile(
                  icon: Icons.payments_outlined,
                  iconColor: kYellow,
                  title: 'Earnings & History',
                  subtitle: 'Completed jobs, invoices and payouts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EarningsPage()),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.star_outline,
                  iconColor: Colors.amberAccent,
                  title: 'My Reviews',
                  subtitle: 'See what customers are saying',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReviewsPage()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section: General ──────────────────────────────────────────
            const _SectionLabel('General'),
            const SizedBox(height: 8),
            _SettingsGroup(
              tiles: [
                _SettingsTile(
                  icon: Icons.settings_outlined,
                  iconColor: Colors.blueGrey,
                  title: 'Settings',
                  subtitle: 'Password, notifications & account',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.support_agent,
                  iconColor: Colors.lightBlueAccent,
                  title: 'Help & Support',
                  subtitle: 'Chat with the IRAMS team',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SupportChatPage(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Prominent Logout button ───────────────────────────────────
            _LogoutButton(
              onPressed: () => _confirmAndLogout(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to receive new job requests.',
        ),
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
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
}

// ── Hero header ────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Contractor contractor;
  const _ProfileHeader({required this.contractor});

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(contractor.fullName);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kYellow.withAlpha(40),
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Large avatar with yellow ring — read-only (shows Admin-approved photo only)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [kYellow, Color(0xFFFFD84D)],
              ),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF2A2A2A),
              backgroundImage: contractor.approvedProfileImageUrl != null &&
                      contractor.approvedProfileImageUrl!.isNotEmpty
                  ? NetworkImage(contractor.approvedProfileImageUrl!)
                  : null,
              child: contractor.approvedProfileImageUrl != null &&
                      contractor.approvedProfileImageUrl!.isNotEmpty
                  ? null
                  : initials.isEmpty
                      ? const Icon(Icons.person, size: 48, color: Colors.white70)
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
            ),
          ),

          const SizedBox(height: 16),

          // Name + verified badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  contractor.fullName.isEmpty ? 'Contractor' : contractor.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (contractor.verificationStatus == 'approved') ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, color: Colors.green, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Email
          if (contractor.email.isNotEmpty)
            Text(
              contractor.email,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),

          // Phone
          if (contractor.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contractor.phone,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 18),

          // Stats row: rating · jobs · status
          // NOTE: Rating and Jobs are derived LIVE from their source-of-truth
          // collections (Contractor/{id}/Reviews and Jobs where
          // ContractorAssigned == me && Status == Completed) rather than from
          // the cached `Rating` / `TotalJobs` fields on the Contractor doc.
          // The cached fields were carrying stale seed data (4.8 / 5).
          Row(
            children: [
              const Expanded(child: _RatingStat()),
              _HeaderDivider(),
              const Expanded(child: _JobsCountStat()),
              _HeaderDivider(),
              Expanded(
                child: _HeaderStat(
                  icon: contractor.isAvailable
                      ? Icons.check_circle
                      : Icons.pause_circle_outline,
                  iconColor:
                      contractor.isAvailable ? Colors.greenAccent : Colors.white54,
                  value: contractor.isAvailable ? 'On' : 'Off',
                  label: 'Status',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white54,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: kBorder,
    );
  }
}

// ── Live-derived Rating stat ───────────────────────────────────────────────
//
// Subscribes to `Contractor/{id}/Reviews` via
// `FirestoreService.instance.watchContractorReviews()` — the SAME stream the
// Reviews page uses — and renders the average `Rating` field across all
// review docs, formatted to one decimal place. Deliberately does NOT read
// the cached `Contractor.Rating` field because that was carrying stale seed
// values; this widget is the single source of truth for the header card.
//
// States:
//   - waiting / no snapshot yet → '-' placeholder
//   - snapshot with empty list  → 'New' (per spec — never a fake number)
//   - snapshot with reviews     → `average.toStringAsFixed(1)`
class _RatingStat extends StatelessWidget {
  const _RatingStat();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: FirestoreService.instance.watchContractorReviews(),
      builder: (context, snap) {
        String value;
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          value = '-';
        } else if (snap.hasError) {
          value = '-';
        } else {
          final reviews = snap.data ?? const <Review>[];
          if (reviews.isEmpty) {
            value = 'New';
          } else {
            final sum = reviews.fold<double>(0, (acc, r) => acc + r.rating);
            final avg = sum / reviews.length;
            value = avg.toStringAsFixed(1);
          }
        }
        return _HeaderStat(
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          value: value,
          label: 'Rating',
        );
      },
    );
  }
}

// ── Live-derived Jobs count stat ───────────────────────────────────────────
//
// Subscribes to `FirestoreService.instance.watchMyJobs()` — the SAME stream
// the Job History page uses (`where ContractorAssigned == <my ref>`) — and
// counts jobs in `JobStatus.completed`. This is the source-of-truth count,
// matching the spec requirement to show jobs where
// `contractorAssigned == currentUser.uid && status == 'Completed'`.
//
// States:
//   - waiting / no snapshot yet → '-' placeholder
//   - snapshot empty / zero     → '0'
//   - otherwise                 → count as string
class _JobsCountStat extends StatelessWidget {
  const _JobsCountStat();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Job>>(
      stream: FirestoreService.instance.watchMyJobs(),
      builder: (context, snap) {
        String value;
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          value = '-';
        } else if (snap.hasError) {
          value = '-';
        } else {
          final jobs = snap.data ?? const <Job>[];
          final completedCount =
              jobs.where((j) => j.status == JobStatus.completed).length;
          value = completedCount.toString();
        }
        return _HeaderStat(
          icon: Icons.work_history_outlined,
          iconColor: Colors.lightBlueAccent,
          value: value,
          label: 'Jobs',
        );
      },
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white54,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Settings grouped container ────────────────────────────────────────────────

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
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white38,
        size: 22,
      ),
    );
  }
}

// ── Logout button ──────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.red.withAlpha(20),
          side: BorderSide(color: Colors.redAccent.withAlpha(120), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Verification banner ────────────────────────────────────────────────────────

class _VerificationBanner extends StatelessWidget {
  final String status;
  const _VerificationBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'approved') {
      // Verified state is now shown as an inline badge on the profile header
      return const SizedBox.shrink();
    }

    // pending_upload, under_review, or rejected — show actionable banner
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;
    switch (status) {
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        title = 'Verification Rejected';
        subtitle = 'Your documents were not approved. Please resubmit.';
        break;
      case 'under_review':
        color = Colors.blue;
        icon = Icons.hourglass_top_outlined;
        title = 'Verification Under Review';
        subtitle =
            'Your documents are being reviewed. You\'ll be notified once approved.';
        break;
      default: // pending_upload
        color = Colors.orange;
        icon = Icons.upload_file_outlined;
        title = 'Upload Documents';
        subtitle =
            'Submit your verification documents to start receiving jobs.';
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => status == 'rejected'
              ? const DocumentStatusPage()
              : const DocumentUploadPage(),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }
}
