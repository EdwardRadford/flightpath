// Connectivity monitoring service — provides a stream of online/offline status
// and a synchronous getter for the current state.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has network connectivity.
///
/// This is a simplified boolean view — it does not distinguish between Wi-Fi,
/// mobile data, etc. It only cares about "can we reach the internet?".
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Emits `true` when the device has connectivity, `false` when offline.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_isConnected);
  }

  /// One-shot check of current connectivity.
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  bool _isConnected(List<ConnectivityResult> results) {
    // ConnectivityResult.none means no connectivity at all.
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Singleton instance of [ConnectivityService].
final connectivityServiceProvider = Provider<ConnectivityService>(
  (_) => ConnectivityService(),
);

/// Stream provider that emits the current connectivity state.
/// Starts with a one-shot check so the first value is available immediately.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  // Emit current state first.
  yield await service.checkConnectivity();
  // Then stream changes.
  yield* service.onConnectivityChanged;
});

/// Convenience provider that returns the current connectivity status.
/// Defaults to `true` (online) while loading to avoid false-positive banners.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).valueOrNull ?? true;
});
