import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isConnected = true;
  ConnectivityResult _currentResult = ConnectivityResult.none;

  /// Current connectivity status
  bool get isConnected => _isConnected;
  
  /// Current connection type
  ConnectivityResult get connectionType => _currentResult;
  
  /// Human-readable connection status
  String get statusText {
    if (!_isConnected) return 'No Connection';
    switch (_currentResult) {
      case ConnectivityResult.wifi:
        return 'WiFi Connected';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Connected';
      default:
        return 'No Connection';
    }
  }

  /// Stream of connectivity changes (simplified boolean)
  Stream<bool> get onConnectivityChanged => _connectivity
      .onConnectivityChanged
      .map((results) => results.isNotEmpty && 
                        results.first != ConnectivityResult.none);

  /// Initialize the service
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);

      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          debugPrint('❌ Connectivity stream error: $error');
        },
      );

      debugPrint('✅ ConnectivityService initialized: $statusText');
    } catch (e) {
      debugPrint('❌ ConnectivityService initialization failed: $e');
      rethrow;
    }
  }

  /// Update connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      _isConnected = false;
      _currentResult = ConnectivityResult.none;
    } else {
      final result = results.first;
      _isConnected = result != ConnectivityResult.none;
      _currentResult = result;
    }

    debugPrint('🌐 Connectivity changed: $statusText');
    notifyListeners();
  }

  /// Check if currently connected
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty && results.first != ConnectivityResult.none;
    } catch (e) {
      debugPrint('❌ Connection check failed: $e');
      return false;
    }
  }

  /// Wait for connection (useful for retry logic)
  Future<void> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isConnected) return;

    final completer = Completer<void>();
    StreamSubscription? sub;

    sub = onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        completer.complete();
        sub?.cancel();
      }
    });

    // Timeout handling
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Connection timeout'));
        sub?.cancel();
      }
    });

    return completer.future;
  }

  /// Dispose resources
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

mixin ConnectivityAwareMixin {
  /// Execute function only if connected, otherwise show error
  Future<T> executeWithConnectivity<T>(
    Future<T> Function() function, {
    String? offlineMessage,
  }) async {
    if (!ConnectivityService.instance.isConnected) {
      throw NoConnectionException(
        offlineMessage ?? 'No internet connection. Please check your network.',
      );
    }
    return await function();
  }

  /// Execute with automatic retry when connection restored
  Future<T> executeWithRetry<T>(
    Future<T> Function() function, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await executeWithConnectivity(function);
      } on NoConnectionException {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        debugPrint('⏳ Retry attempt $attempts/$maxRetries after ${retryDelay.inSeconds}s');
        await Future.delayed(retryDelay);
      }
    }
    
    throw Exception('Max retries exceeded');
  }
}

/// Custom exception for connectivity issues
class NoConnectionException implements Exception {
  final String message;
  NoConnectionException(this.message);

  @override
  String toString() => message;
}