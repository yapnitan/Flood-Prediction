import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../services/offline_sync_service.dart';

/// Shown at the top of a screen while the device is offline, so "why isn't
/// this saving/updating" has an obvious answer. Collapses to nothing once
/// back online.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onStatusChange,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (isOnline) return const SizedBox.shrink();

        return FutureBuilder<int>(
          future: OfflineSyncService.instance.pendingOperationCount(),
          builder: (context, pendingSnapshot) {
            final pending = pendingSnapshot.data ?? 0;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pending > 0
                          ? "You're offline — $pending change${pending == 1 ? '' : 's'} will sync automatically once you're back online."
                          : "You're offline — showing the last saved data.",
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
