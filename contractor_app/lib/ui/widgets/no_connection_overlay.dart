import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// Shows a persistent banner at the top when offline
/// Auto-hides when connection is restored

class NoConnectionOverlay extends StatelessWidget {
  const NoConnectionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onConnectivityChanged,
      initialData: ConnectivityService.instance.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;

        // Don't show anything if connected
        if (isConnected) {
          return const SizedBox.shrink();
        }

        // Show offline banner
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No internet connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'OFFLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ✅ Alternative: Offline mode indicator (subtle)
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onConnectivityChanged,
      initialData: ConnectivityService.instance.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;

        if (isConnected) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 14,
                color: Colors.redAccent.shade200,
              ),
              const SizedBox(width: 6),
              Text(
                'Offline Mode',
                style: TextStyle(
                  color: Colors.redAccent.shade200,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
