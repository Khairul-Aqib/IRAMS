import 'package:flutter/material.dart';

import 'package:user_app/services/unread_messages_service.dart';

/// Drop-in replacement for the `Builder` + `IconButton(Icons.menu)` burger
/// pattern used on every drawer-host page. Adds a red unread-count badge in
/// the top-right corner of the icon when [UnreadMessagesService] reports any
/// unread messages.
///
/// Usage on an AppBar:
///   appBar: AppBar(
///     leading: const UnreadMenuButton(),
///     ...
///   )
///
/// The widget owns no streams of its own — it just listens to the singleton
/// [UnreadMessagesService.instance.count]. Mounting it on a page calls
/// [UnreadMessagesService.start] (idempotent), which lazily kicks off the
/// underlying Firestore listeners on first use.
class UnreadMenuButton extends StatefulWidget {
  /// Icon colour. Most pages use white; the homepage uses white too. Override
  /// per page if a different colour is needed.
  final Color iconColor;

  /// Background ring colour for the badge — matches the AppBar background
  /// behind the icon so the badge appears to sit in front of the icon
  /// without a harsh edge. Defaults to the standard top-bar `Colors.black`.
  final Color badgeRing;

  const UnreadMenuButton({
    super.key,
    this.iconColor = Colors.white,
    this.badgeRing = Colors.black,
  });

  @override
  State<UnreadMenuButton> createState() => _UnreadMenuButtonState();
}

class _UnreadMenuButtonState extends State<UnreadMenuButton> {
  @override
  void initState() {
    super.initState();
    UnreadMessagesService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => IconButton(
        onPressed: () => Scaffold.of(ctx).openDrawer(),
        icon: ValueListenableBuilder<int>(
          valueListenable: UnreadMessagesService.instance.count,
          builder: (context, unread, _) {
            return SizedBox(
              width: 32,
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.menu, color: widget.iconColor),
                  if (unread > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.badgeRing,
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
            );
          },
        ),
      ),
    );
  }
}
