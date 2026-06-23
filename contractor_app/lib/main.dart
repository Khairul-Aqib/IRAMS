import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/firestore_service.dart';
import 'firebase_options.dart' as firebase_config;
import 'ui/pages/auth/login_page.dart';
import 'ui/pages/auth/register_page.dart';
import 'ui/pages/home/shell_page.dart';
import 'ui/pages/auth/mfa_gate_page.dart';
import 'ui/widgets/no_connection_overlay.dart';

/// Top-level background message handler. Runs in its own isolate when the app
/// is terminated or fully backgrounded. Firebase auto-displays the notification;
/// this handler ensures Firebase is initialised in the background isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: firebase_config.FirebaseConfig.currentPlatform,
  );
}

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode (better UX for contractors)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style (status bar, navigation bar)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded');
  } catch (e) {
    debugPrint('⚠️ .env file not found (using defaults): $e');
    // Non-critical, app can continue
  }

  // Initialize Firebase with error handling
  try {
    if (firebase_config.FirebaseConfig.validateConfig()) {
      await Firebase.initializeApp(
        options: firebase_config.FirebaseConfig.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');

      // Register background message handler (must be after Firebase.initializeApp)
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } else {
      debugPrint('❌ Firebase configuration validation failed');
      // In production, show error screen instead of crashing
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    // In production, send error to crash reporting service (e.g., Sentry)
  }

  // Initialize connectivity monitoring (optional but recommended)
  try {
    await ConnectivityService.instance.initialize();
    debugPrint('✅ Connectivity service initialized');
  } catch (e) {
    debugPrint('⚠️ Connectivity service initialization failed: $e');
    // Non-critical, app can continue
  }

  // ── Global Safety Net ──
  // Catch synchronous Flutter framework errors (widget build failures, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('⚠️ FlutterError caught: ${details.exceptionAsString()}');
  };

  // Catch asynchronous Dart errors that escape all try/catch blocks.
  // Returning true prevents the runtime from terminating the isolate.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('⚠️ Unhandled async error: $error');
    debugPrint('$stack');
    return true;
  };

  // Run the app with error boundary
  runApp(const ContractorApp());
}



class ContractorApp extends StatefulWidget {
  const ContractorApp({super.key});

  @override
  State<ContractorApp> createState() => _ContractorAppState();
}

class _ContractorAppState extends State<ContractorApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final auth = AuthService.instance;

    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: auth,

      // Global error handling for navigation
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Navigation Error', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(state.error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),

      redirect: (context, state) async {
        final loggedIn = auth.currentUser != null;
        final currentPath = state.matchedLocation;

        // Auth pages (no redirect enforcement on these paths)
        final isAuthPage = currentPath == '/login' ||
                          currentPath == '/register' ||
                          currentPath == '/mfa';

        debugPrint('🔄 Navigation: $currentPath (loggedIn: $loggedIn)');

        // Not logged in → force login (except if already on auth pages)
        if (!loggedIn && !isAuthPage) {
          debugPrint('➡️ Redirecting to /login');
          return '/login';
        }

        // Logged in but on auth pages → enforce MFA (email verification not required)
        if (loggedIn && (currentPath == '/login' || currentPath == '/register')) {
          // Check if MFA is required
          final hasMfa = await auth.hasMfaEnrolled();
          if (!hasMfa) {
            debugPrint('➡️ Redirecting to /mfa (MFA not enrolled)');
            return '/mfa';
          }
          debugPrint('➡️ Redirecting to / (already logged in)');
          return '/';
        }

        // Logged in, on any non-auth page: enforce MFA only
        // (email verification gate removed for development; re-enable before production)
        if (loggedIn && currentPath != '/mfa') {
          final hasMfa = await auth.hasMfaEnrolled();
          if (!hasMfa) {
            debugPrint('➡️ Redirecting to /mfa (MFA not enrolled)');
            return '/mfa';
          }
        }

        // All good, continue
        return null;
      },

      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/mfa',
          name: 'mfa',
          builder: (context, state) => MfaGatePage(
            phoneNumber: state.extra as String?,
          ),
        ),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const ShellPage(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed — clearing FirestoreService cache');
      // Clears the cached contractor doc ID so the next stream subscription
      // re-resolves it fresh. Firestore streams reconnect automatically;
      // this ensures stale lookups from before backgrounding are discarded.
      FirestoreService.instance.clearCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IRAMS Contractor',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      routerConfig: _router,
      
      // Global error handling
      builder: (context, child) {
        // Add global error boundary
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exception.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        // Wrap app with connectivity overlay (shows banner when offline)
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const NoConnectionOverlay(),
          ],
        );
      },
    );
  }
}

