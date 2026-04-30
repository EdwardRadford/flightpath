// Connectivity banner — shows a subtle offline notification, pending sync
// count, and a brief "all synced" confirmation after items finish syncing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/services/connectivity_service.dart';
import 'package:flight_path/shared/services/sync_service.dart';
import 'package:flight_path/core/theme/app_theme.dart';

/// A slim banner that slides in at the top of the screen when the device is
/// offline, shows pending sync count, and briefly flashes a success message
/// when all items have synced.
///
/// Place this at the top of a Column above the screen body.
class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  /// Tracks whether we recently transitioned from pending > 0 to 0
  /// while online, so we can show a brief "All synced" confirmation.
  bool _showSyncedConfirmation = false;
  int _previousPendingCount = 0;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    // Detect transition from pending > 0 → 0 while online.
    if (isOnline &&
        _previousPendingCount > 0 &&
        pendingCount == 0 &&
        !_showSyncedConfirmation) {
      _showSyncedConfirmation = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showSyncedConfirmation = false);
        }
      });
    }
    _previousPendingCount = pendingCount;

    // Show banner when offline, syncing, or just-synced confirmation.
    final showBanner = !isOnline || pendingCount > 0 || _showSyncedConfirmation;

    if (!showBanner) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: const SizedBox.shrink(),
      );
    }

    // Determine banner style.
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String message;

    if (!isOnline && pendingCount > 0) {
      bgColor = AppColors.warning.withValues(alpha: 0.15);
      fgColor = AppColors.warning;
      icon = Icons.cloud_off;
      message =
          "You're offline \u2014 $pendingCount item${pendingCount == 1 ? '' : 's'} saved, will sync when connected";
    } else if (!isOnline) {
      bgColor = AppColors.warning.withValues(alpha: 0.15);
      fgColor = AppColors.warning;
      icon = Icons.cloud_off;
      message = "You're offline \u2014 data will sync when connected";
    } else if (pendingCount > 0) {
      bgColor = AppColors.primary.withValues(alpha: 0.10);
      fgColor = AppColors.primary;
      icon = Icons.sync;
      message =
          'Syncing $pendingCount item${pendingCount == 1 ? '' : 's'}\u2026';
    } else {
      // Synced confirmation.
      bgColor = AppColors.success.withValues(alpha: 0.12);
      fgColor = AppColors.success;
      icon = Icons.cloud_done;
      message = 'All changes synced';
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: bgColor,
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 16, color: fgColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a screen body with a [ConnectivityBanner] at the top.
/// Use this on full-screen routes outside the [MainShell] that need
/// offline awareness (e.g. debrief, logbook entry).
class ConnectivityAwareBody extends StatelessWidget {
  final Widget child;
  const ConnectivityAwareBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ConnectivityBanner(),
        Expanded(child: child),
      ],
    );
  }
}
