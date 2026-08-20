import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around [Connectivity] — the single source of truth for
/// "is this device online right now" that [OfflineSyncService] and any
/// service doing offline-aware reads/writes check against.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _statusController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Emits only on actual online/offline transitions, not every connectivity
  /// event (e.g. wifi -> mobile data while already online is not a
  /// transition callers care about here).
  Stream<bool> get onStatusChange => _statusController.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _isConnected(results);
      if (_isOnline != wasOnline) _statusController.add(_isOnline);
    });
  }

  bool _isConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
