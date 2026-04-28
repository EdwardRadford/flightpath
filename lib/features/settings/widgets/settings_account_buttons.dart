import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/services/auth_service.dart';
import 'package:flight_path/shared/services/content_cache_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';

// ---------------------------------------------------------------------------
// Notifications section
// ---------------------------------------------------------------------------
class SettingsNotificationsSection extends StatelessWidget {
  const SettingsNotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => context.push('/settings/notifications'),
        leading: Icon(Icons.notifications_rounded,
            color: cs.onSurface.withValues(alpha: 0.6)),
        title: Text(
          'Notification Preferences',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Lesson reminders, spaced repetition, and more.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline download tile
// ---------------------------------------------------------------------------
class SettingsOfflineDownloadTile extends ConsumerStatefulWidget {
  const SettingsOfflineDownloadTile({super.key});

  @override
  ConsumerState<SettingsOfflineDownloadTile> createState() =>
      _SettingsOfflineDownloadTileState();
}

class _SettingsOfflineDownloadTileState
    extends ConsumerState<SettingsOfflineDownloadTile> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final cacheService = ref.read(contentCacheServiceProvider);
      final count = await cacheService.prefetchAllContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Content downloaded successfully ($count exercises)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: _downloading ? null : _download,
        leading: Icon(Icons.cloud_download_outlined,
            color: cs.onSurface.withValues(alpha: _downloading ? 0.3 : 0.6)),
        title: Text(
          'Download for Offline',
          style: TextStyle(
            color:
                cs.onSurface.withValues(alpha: _downloading ? 0.4 : 1.0),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Save all exercises, briefs, and quizzes for offline use',
          style: TextStyle(
            color: cs.onSurface
                .withValues(alpha: _downloading ? 0.3 : 0.6),
            fontSize: 12,
          ),
        ),
        trailing: _downloading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign Out button
// ---------------------------------------------------------------------------
class SettingsSignOutButton extends ConsumerWidget {
  const SettingsSignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _confirmSignOut(context),
        leading: Icon(Icons.logout_rounded, color: cs.error),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: cs.error,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Any unsaved data will be lost.',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              FirebaseAnalytics.instance.logEvent(name: 'sign_out');
              await AuthService().signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete Account button
// ---------------------------------------------------------------------------
class SettingsDeleteAccountButton extends ConsumerStatefulWidget {
  const SettingsDeleteAccountButton({super.key});

  @override
  ConsumerState<SettingsDeleteAccountButton> createState() =>
      _SettingsDeleteAccountButtonState();
}

class _SettingsDeleteAccountButtonState
    extends ConsumerState<SettingsDeleteAccountButton> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'This will permanently delete your account and all your lesson data. '
          'This cannot be undone.',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete Account',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final uid = user.uid;

      await FirebaseAnalytics.instance.logEvent(name: 'account_deleted');

      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteAllUserData(uid);

      await AuthService().signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to delete account. Please try again or contact support.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        onTap: _deleting ? null : _confirmAndDelete,
        leading: _deleting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.error,
                ),
              )
            : Icon(Icons.delete_forever_rounded, color: cs.error),
        title: Text(
          _deleting ? 'Deleting account\u2026' : 'Delete Account',
          style: TextStyle(
            color: _deleting
                ? cs.error.withValues(alpha: 0.5)
                : cs.error,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Permanently removes your account and all data.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
