import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:user_app/services/unread_messages_service.dart';
import 'package:user_app/ui/pages/home/about_us.dart';
import 'package:user_app/ui/pages/home/homepage.dart';
import 'package:user_app/ui/pages/home/history.dart';
import 'package:user_app/ui/pages/home/knowledge_base.dart';
import 'package:user_app/ui/pages/home/petrol_prices.dart';
import 'package:user_app/ui/pages/home/car_list.dart';
import 'package:user_app/constants/colors.dart';
import 'package:user_app/services/user_firestore_service.dart';
import 'package:user_app/ui/pages/messages/message_inbox_page.dart';
import 'package:user_app/ui/pages/messages/support_chat_page.dart';
import 'package:user_app/ui/pages/home/notification.dart';
import 'package:user_app/ui/pages/auth/login.dart';
import 'package:user_app/ui/pages/home/user_profile.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// PROFILE HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // CLICKABLE PROFILE AREA (avatar + name/phone) — both driven
                  // by the same Users/{doc} stream so they stay in sync.
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const UserProfile()),
                        );
                      },
                      child: const _DrawerHeaderContent(),
                    ),
                  ),

                  // NOTIFICATION BUTTON
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none,
                          color: kYellow,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// CHAT BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                  ),
                  onPressed: () async {
                    // Capture the Navigator before the await — the drawer's
                    // BuildContext gets unmounted as it animates closed, so
                    // checking `context.mounted` after the async gap can
                    // silently swallow the navigation on subsequent taps.
                    final nav = Navigator.of(context);
                    nav.pop(); // close drawer
                    await _ensureSupportThread();
                    // Land on Support no matter how deep the user was — the
                    // stack collapses down to the root + SupportChatPage so
                    // back-button always returns to home, never strands them
                    // mid-flow on some other screen.
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const SupportChatPage(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    'Chat with Us',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.grey),

            /// MAIN MENU
            _item(context, Icons.home, 'Home', const HomePage()),
            const _MessagesDrawerItem(),
            _item(
              context,
              Icons.directions_car,
              'My Vehicles',
              const CarListPage(),
            ),
            _item(context, Icons.history, 'History', const HistoryPage()),
            _item(
              context,
              Icons.local_gas_station,
              'Petrol Prices',
              const PetrolPricesPage(),
            ),
            _item(
              context,
              Icons.menu_book,
              'Knowledge Base',
              const KnowledgeBasePage(),
            ),

            const Spacer(),
            const Divider(color: Colors.grey),

            _item(context, Icons.group, 'About Us', const AboutUsPage()),

            /// LOGOUT BUTTON
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    UserFirestoreService.instance.clearCache();
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Make sure the user has a SupportChats/{customId} parent doc so the inbox
  /// shows a Support tile immediately, before they send their first message.
  /// Idempotent — only writes when the doc is missing.
  Future<void> _ensureSupportThread() async {
    final id = await UserFirestoreService.instance.getCustomUserId();
    if (id.isEmpty) return;
    final ref =
        FirebaseFirestore.instance.collection('SupportChats').doc(id);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'userId': id,
      'lastMessage': 'How can we help?',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// DRAWER ITEM
  Widget _item(BuildContext context, IconData icon, String text, Widget? page) {
    return ListTile(
      leading: Icon(icon, color: kYellow),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        if (page != null) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => page));
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Real-time header driven by the Users/{uid} snapshot.
// ---------------------------------------------------------------------------

class _DrawerHeaderContent extends StatelessWidget {
  const _DrawerHeaderContent();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Row(
        children: const [
          _AvatarBadge(imageUrl: null),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Not signed in',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .snapshots(),
      builder: (context, qSnap) {
        final data = qSnap.hasData && qSnap.data!.docs.isNotEmpty
            ? qSnap.data!.docs.first.data()
            : const <String, dynamic>{};
        return _renderFromData(user, data);
      },
    );
  }

  Widget _renderFromData(User user, Map<String, dynamic> data) {
    final fullName = (data['fullName'] ?? '').toString();
    final displayName = fullName.isNotEmpty
        ? fullName
        : (user.displayName ?? user.email ?? '');
    final phone = (data['phone'] ?? '').toString();
    final imageUrl = (data['profileImageUrl'] ?? '').toString();

    return Row(
      children: [
        _AvatarBadge(imageUrl: imageUrl.isEmpty ? null : imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                phone.isNotEmpty ? phone : (user.email ?? ''),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar with an amber border + soft shadow so it pops against the dark
// drawer. Shimmer placeholder while the image loads; falls back to the
// default person icon on error or when no URL has been uploaded yet.
// ---------------------------------------------------------------------------

class _AvatarBadge extends StatelessWidget {
  final String? imageUrl;
  const _AvatarBadge({required this.imageUrl});

  static const double _radius = 26;
  static const double _diameter = _radius * 2;

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kYellow, width: 2),
        boxShadow: [
          BoxShadow(
            color: kYellow.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: _diameter,
                height: _diameter,
                fit: BoxFit.cover,
                placeholder: (_, __) => _shimmerPlaceholder(),
                errorWidget: (_, __, ___) => _fallbackIcon(),
              )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _shimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3F3F3F),
      child: Container(
        width: _diameter,
        height: _diameter,
        color: const Color(0xFF2A2A2A),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: _diameter,
      height: _diameter,
      color: Colors.grey,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Colors.black),
    );
  }
}

// =============================================================================
// Messages drawer item with live unread badge. Reads from the singleton
// [UnreadMessagesService] so the count stays in sync with the burger-button
// badges on each page (single subscription pool, single source of truth).
// =============================================================================

class _MessagesDrawerItem extends StatefulWidget {
  const _MessagesDrawerItem();

  @override
  State<_MessagesDrawerItem> createState() => _MessagesDrawerItemState();
}

class _MessagesDrawerItemState extends State<_MessagesDrawerItem> {
  @override
  void initState() {
    super.initState();
    UnreadMessagesService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: UnreadMessagesService.instance.count,
      builder: (context, unread, _) {
        return ListTile(
          leading: SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.message, color: kYellow),
                if (unread > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF121212),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: const Text('Messages',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MessageInboxPage()),
            );
          },
        );
      },
    );
  }
}
