import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'user_firestore_service.dart';

/// Singleton that maintains a live unread-messages count for the current user
/// across all chats (per-job and support). Multiple widgets (the drawer item,
/// each page's burger badge) share the same subscription pool — so navigating
/// between pages doesn't tear down and re-open streams.
///
/// Lifecycle:
///   • [start] is idempotent — call it from any widget that wants to listen.
///     Bootstraps the Firestore listeners on first call; further calls no-op.
///   • Listen to [count] (a [ValueNotifier]<int>) for live updates.
///   • The service intentionally has no teardown — the data is small and
///     the streams cost essentially nothing once Firestore has cached them.
///     A future [reset] hook can clear state on logout if needed.
///
/// Counting rules:
///   • Job chat   → message counts as unread when senderId ≠ currentUid AND
///                  createdAt > Users/{U***}.lastReadAt['job_{jobId}'].
///   • Support    → message counts as unread when isFromAdmin == true AND
///                  createdAt > Users/{U***}.lastReadAt['support'].
///
/// `lastReadAt` is written by `chat_detail.dart` whenever the user opens or
/// receives messages within an open chat.
class UnreadMessagesService {
  UnreadMessagesService._();
  static final UnreadMessagesService instance = UnreadMessagesService._();

  /// Live count exposed to UI. Drives both the drawer item and the burger
  /// badge — single source of truth so they can never disagree.
  final ValueNotifier<int> count = ValueNotifier<int>(0);

  bool _started = false;

  String? _customId;
  String _currentUid = '';

  StreamSubscription? _userSub;
  StreamSubscription? _jobsSub;
  StreamSubscription? _supportMsgsSub;

  /// chatKey ('job_{id}' or 'support') → live message subscription.
  final Map<String, StreamSubscription> _msgSubs = {};

  /// chatKey → cached latest snapshot (so we can recompute the count when
  /// lastReadAt changes without re-reading messages).
  final Map<String, QuerySnapshot<Map<String, dynamic>>> _msgSnapshots = {};

  /// chatKey → the user's last-read timestamp for that chat.
  Map<String, Timestamp> _lastReadAt = {};

  Set<String> _activeJobIds = {};

  /// Idempotent. Safe to call from every widget that wants the count.
  void start() {
    if (_started) return;
    _started = true;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final id = await UserFirestoreService.instance.getCustomUserId();
    if (id.isEmpty) {
      // Not linked yet — the count stays at 0. Allow re-bootstrap later
      // if the user finishes registration.
      _started = false;
      return;
    }
    _customId = id;
    _subscribeUser(id);
    _subscribeJobs(id);
    _subscribeSupportMessages(id);
  }

  void _subscribeUser(String id) {
    _userSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(id)
        .snapshots()
        .listen((snap) {
      final raw = snap.data()?['lastReadAt'];
      final next = <String, Timestamp>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (k is String && v is Timestamp) next[k] = v;
        });
      }
      _lastReadAt = next;
      _recompute();
    });
  }

  void _subscribeJobs(String id) {
    final userPath = '/Users/$id';
    _jobsSub = FirebaseFirestore.instance
        .collection('Jobs')
        .where('UserID', isEqualTo: userPath)
        .snapshots()
        .listen((snap) {
      final newJobIds = snap.docs.map((d) => d.id).toSet();

      // Cancel subs for jobs no longer in the result.
      for (final jobId in _activeJobIds.difference(newJobIds)) {
        final key = 'job_$jobId';
        _msgSubs[key]?.cancel();
        _msgSubs.remove(key);
        _msgSnapshots.remove(key);
      }
      // Open subs for newly-appearing jobs.
      for (final jobId in newJobIds.difference(_activeJobIds)) {
        _subscribeJobMessages(jobId);
      }

      _activeJobIds = newJobIds;
      _recompute();
    });
  }

  void _subscribeJobMessages(String jobId) {
    final key = 'job_$jobId';
    _msgSubs[key] = FirebaseFirestore.instance
        .collection('Jobs')
        .doc(jobId)
        .collection('messages')
        .snapshots()
        .listen((snap) {
      _msgSnapshots[key] = snap;
      _recompute();
    });
  }

  void _subscribeSupportMessages(String id) {
    _supportMsgsSub = FirebaseFirestore.instance
        .collection('SupportChats')
        .doc(id)
        .collection('messages')
        .snapshots()
        .listen((snap) {
      _msgSnapshots['support'] = snap;
      _recompute();
    });
  }

  /// Counts unread messages in a single chat.
  int _unreadFor(String chatKey) {
    final snap = _msgSnapshots[chatKey];
    if (snap == null) return 0;
    final lastRead = _lastReadAt[chatKey];
    final isSupport = chatKey == 'support';
    var count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      // Tolerate either casing — job mode uses PascalCase, support camelCase.
      final ts = data['CreatedAt'] ?? data['createdAt'];
      if (ts is! Timestamp) continue;

      final notMine = isSupport
          ? data['isFromAdmin'] == true
          : ((data['SenderId'] ?? data['senderId'])?.toString() != _currentUid);
      if (!notMine) continue;

      if (lastRead == null || ts.compareTo(lastRead) > 0) count++;
    }
    return count;
  }

  void _recompute() {
    var total = 0;
    for (final key in _msgSnapshots.keys) {
      total += _unreadFor(key);
    }
    count.value = total;
  }
}
