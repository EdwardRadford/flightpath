import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _SyncState { saving, syncing, synced, hidden }

final offlineSyncIndicatorProvider =
    StateNotifierProvider<_SyncNotifier, _SyncState>(
  (ref) => _SyncNotifier(),
);

class _SyncNotifier extends StateNotifier<_SyncState> {
  Timer? _hideTimer;
  _SyncNotifier() : super(_SyncState.hidden);

  void onOfflineSave() {
    _hideTimer?.cancel();
    state = _SyncState.saving;
  }

  void onNetworkRestored() {
    if (state == _SyncState.saving) state = _SyncState.syncing;
  }

  void onSyncComplete() {
    state = _SyncState.synced;
    _hideTimer = Timer(
      const Duration(seconds: 2),
      () => state = _SyncState.hidden,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

class OfflineSyncIndicator extends ConsumerWidget {
  const OfflineSyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(offlineSyncIndicatorProvider);
    if (syncState == _SyncState.hidden) return const SizedBox.shrink();

    final (color, icon, label) = switch (syncState) {
      _SyncState.saving => (
          Colors.amber.shade700,
          Icons.cloud_off_rounded,
          'Saving offline',
        ),
      _SyncState.syncing => (
          Colors.blue.shade400,
          Icons.cloud_sync_rounded,
          'Syncing now',
        ),
      _SyncState.synced => (
          Colors.green.shade400,
          Icons.cloud_done_rounded,
          'All synced',
        ),
      _SyncState.hidden => (
          Colors.transparent,
          Icons.cloud_done_rounded,
          '',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
