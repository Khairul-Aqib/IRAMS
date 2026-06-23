import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firestore_service.dart';

/// Handles all Firebase Cloud Messaging concerns:
///   - Permission requests & token storage
///   - Terminated-state tap  (getInitialMessage)
///   - Background-state tap  (onMessageOpenedApp)
///   - Foreground message    (onMessage) — shows a system tray notification
///     via flutter_local_notifications AND emits to a stream for in-app UI
///
/// Navigation is deliberately NOT done here. FcmService is a plain singleton
/// with no access to BuildContext. Instead it exposes two streams that
/// ShellPage (which owns a BuildContext) subscribes to:
///
///   • [onJobTap]          — emits a jobId when a notification is tapped
///   • [onForegroundMessage] — emits the full message while the app is open
///
/// For the terminated-state case, [consumePendingJobId] returns a buffered
/// jobId that ShellPage should check once its initState has completed.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  // ── Local notifications ───────────────────────────────────────────────────

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'irams_contractor_jobs',
    'Job Alerts',
    description: 'Notifications for new job requests and updates',
    importance: Importance.high,
  );

  // ── Streams ────────────────────────────────────────────────────────────────

  final _jobTapController = StreamController<String>.broadcast();
  final _foregroundMsgController = StreamController<RemoteMessage>.broadcast();

  /// Emits a jobId when a notification is tapped (background, terminated,
  /// or foreground local notification).
  Stream<String> get onJobTap => _jobTapController.stream;

  /// Emits the full [RemoteMessage] when a notification arrives while the app
  /// is in the foreground.
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMsgController.stream;

  // ── Internal subscriptions ────────────────────────────────────────────────

  StreamSubscription? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;

  /// Cancels all internal subscriptions. Call when the app is permanently
  /// torn down (e.g., sign-out flow). In normal use the singleton lives for
  /// the full app lifetime so this is rarely needed.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _onMessageSub?.cancel();
    _jobTapController.close();
    _foregroundMsgController.close();
  }

  // ── Terminated-state buffer ────────────────────────────────────────────────

  String? _pendingJobId;

  /// Returns the jobId buffered from a terminated-state notification tap, then
  /// clears the buffer so it is only consumed once.
  String? consumePendingJobId() {
    final id = _pendingJobId;
    _pendingJobId = null;
    return id;
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Call once from [ShellPage.initState] (or equivalent entry point).
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // 1. Request OS-level permissions (handles Android 13+ POST_NOTIFICATIONS)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Persist the FCM token using the existing updateFcmToken helper
    final token = await messaging.getToken();
    if (token != null) {
      await FirestoreService.instance.updateFcmToken(token);
    }

    // 3. Keep the token fresh automatically on rotation
    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      FirestoreService.instance.updateFcmToken(newToken);
    });

    // 4. Initialise flutter_local_notifications for foreground display
    await _initLocalNotifications();

    // 5. TERMINATED STATE ─────────────────────────────────────────────────
    //    The app was completely killed and the user tapped the notification.
    //    getInitialMessage() returns the message that launched the app.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final jobId = _extractJobId(initialMessage);
      if (jobId != null) {
        // Buffer it; ShellPage will consume this once its widget tree is ready.
        _pendingJobId = jobId;
      }
    }

    // 6. BACKGROUND STATE ─────────────────────────────────────────────────
    //    The app is running but in the background. User taps the system tray
    //    notification to bring it to the foreground.
    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final jobId = _extractJobId(message);
      if (jobId != null) {
        _jobTapController.add(jobId);
      }
    });

    // 7. FOREGROUND STATE ─────────────────────────────────────────────────
    //    The app is fully open. FCM does NOT show a system tray notification
    //    in this state, so we:
    //      a) Show a local notification in the system tray
    //      b) Emit to the stream so ShellPage can also show an in-app SnackBar
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _foregroundMsgController.add(message);
    });
  }

  // ── Local notifications setup ─────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create the Android notification channel (no-op if it already exists).
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  /// Called when the user taps a local notification shown while the app was
  /// in the foreground. Extracts the jobId from the payload and pushes it to
  /// the same [onJobTap] stream that background/terminated taps use.
  void _onLocalNotificationTap(NotificationResponse response) {
    final jobId = response.payload;
    if (jobId != null && jobId.isNotEmpty) {
      _jobTapController.add(jobId);
    }
  }

  /// Displays a system tray notification for an FCM message received while the
  /// app is in the foreground.
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    try {
      _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'IRAMS',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: _extractJobId(message),
      );
    } catch (e) {
      debugPrint('Failed to show local notification: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _extractJobId(RemoteMessage message) {
    final id = message.data['jobId'] as String?;
    return (id != null && id.isNotEmpty) ? id : null;
  }
}
