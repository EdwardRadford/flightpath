// Per-type notification preferences screen — master toggle plus individual
// controls for each notification category. Manages FCM topic subscriptions
// and persists preferences to SharedPreferences + Firestore.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/notification_service.dart';

// ---------------------------------------------------------------------------
// Notification preferences provider
// ---------------------------------------------------------------------------

/// Loads and caches the user's notification preferences map.
final _notificationPrefsProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  return NotificationService.loadPreferences();
});

// ---------------------------------------------------------------------------
// NotificationPreferencesScreen
// ---------------------------------------------------------------------------

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  /// Local copy of preferences so toggles respond immediately while the
  /// async save runs in the background.
  Map<String, bool> _prefs = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance
        .logEvent(name: 'notification_preferences_opened');
  }

  void _initFromAsync(Map<String, bool> loaded) {
    if (!_loaded) {
      _prefs = Map<String, bool>.from(loaded);
      _loaded = true;
    }
  }

  bool _get(String key) => _prefs[key] ?? true;

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);

    // If master toggle is turned off, disable all individual toggles too.
    if (key == NotificationPrefKeys.masterEnabled && !value) {
      setState(() {
        _prefs[NotificationPrefKeys.lessonReminders] = false;
        _prefs[NotificationPrefKeys.preparationPrompts] = false;
        _prefs[NotificationPrefKeys.spacedRepetition] = false;
        _prefs[NotificationPrefKeys.inactivityNudges] = false;
      });
      await Future.wait([
        NotificationService.savePreference(key: key, value: value),
        NotificationService.savePreference(
            key: NotificationPrefKeys.lessonReminders, value: false),
        NotificationService.savePreference(
            key: NotificationPrefKeys.preparationPrompts, value: false),
        NotificationService.savePreference(
            key: NotificationPrefKeys.spacedRepetition, value: false),
        NotificationService.savePreference(
            key: NotificationPrefKeys.inactivityNudges, value: false),
      ]);
    } else if (key == NotificationPrefKeys.masterEnabled && value) {
      // Master turned on — re-enable all individual toggles.
      setState(() {
        _prefs[NotificationPrefKeys.lessonReminders] = true;
        _prefs[NotificationPrefKeys.preparationPrompts] = true;
        _prefs[NotificationPrefKeys.spacedRepetition] = true;
        _prefs[NotificationPrefKeys.inactivityNudges] = true;
      });
      await Future.wait([
        NotificationService.savePreference(key: key, value: value),
        NotificationService.savePreference(
            key: NotificationPrefKeys.lessonReminders, value: true),
        NotificationService.savePreference(
            key: NotificationPrefKeys.preparationPrompts, value: true),
        NotificationService.savePreference(
            key: NotificationPrefKeys.spacedRepetition, value: true),
        NotificationService.savePreference(
            key: NotificationPrefKeys.inactivityNudges, value: true),
      ]);
    } else {
      await NotificationService.savePreference(key: key, value: value);
    }

    if (!mounted) return;
    // Invalidate the provider cache so future reads are fresh.
    ref.invalidate(_notificationPrefsProvider);

    FirebaseAnalytics.instance.logEvent(
      name: 'notification_preference_changed',
      parameters: {'key': key, 'enabled': value.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(_notificationPrefsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: prefsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: cs.primary)),
        error: (_, __) => Center(
          child: Text(
            'Unable to load preferences. Please try again.',
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (loaded) {
          _initFromAsync(loaded);
          final masterEnabled = _get(NotificationPrefKeys.masterEnabled);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Master toggle ──────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'All Notifications',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Turn off to silence all Flight Path Training notifications.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  value: masterEnabled,
                  onChanged: (v) =>
                      _toggle(NotificationPrefKeys.masterEnabled, v),
                  activeThumbColor: cs.primary,
                ),
              ),

              const SizedBox(height: 20),

              // ── Individual toggles (dimmed when master is off) ─────────
              AnimatedOpacity(
                opacity: masterEnabled ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !masterEnabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'NOTIFICATION TYPES'),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _PreferenceToggle(
                              title: 'Lesson Reminders',
                              subtitle:
                                  'Reminder the evening before a scheduled lesson.',
                              icon: Icons.event_note_rounded,
                              value: _get(
                                  NotificationPrefKeys.lessonReminders),
                              onChanged: (v) => _toggle(
                                  NotificationPrefKeys.lessonReminders, v),
                            ),
                            Divider(
                                color: cs.outline, height: 1, indent: 56),
                            _PreferenceToggle(
                              title: 'Preparation Prompts',
                              subtitle:
                                  '2 hours after completing your preparation.',
                              icon: Icons.auto_stories_rounded,
                              value: _get(
                                  NotificationPrefKeys.preparationPrompts),
                              onChanged: (v) => _toggle(
                                  NotificationPrefKeys.preparationPrompts,
                                  v),
                            ),
                            Divider(
                                color: cs.outline, height: 1, indent: 56),
                            _PreferenceToggle(
                              title: 'Spaced Repetition',
                              subtitle:
                                  'Review reminders at 1, 3, 7, and 14 day intervals.',
                              icon: Icons.replay_rounded,
                              value: _get(
                                  NotificationPrefKeys.spacedRepetition),
                              onChanged: (v) => _toggle(
                                  NotificationPrefKeys.spacedRepetition, v),
                            ),
                            Divider(
                                color: cs.outline, height: 1, indent: 56),
                            _PreferenceToggle(
                              title: 'Inactivity Nudges',
                              subtitle:
                                  "Gentle reminder if you haven't flown in 7 days.",
                              icon: Icons.notifications_active_rounded,
                              value: _get(
                                  NotificationPrefKeys.inactivityNudges),
                              onChanged: (v) => _toggle(
                                  NotificationPrefKeys.inactivityNudges, v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Quiet hours note ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.bedtime_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiet Hours',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Notifications are automatically silenced between 10pm and 8am. '
                            'Any notification triggered during this window will be delivered at 8am.',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.5),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual preference toggle tile
// ---------------------------------------------------------------------------

class _PreferenceToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SwitchListTile(
      secondary: Icon(icon, color: cs.onSurface.withValues(alpha: 0.6)),
      title: Text(
        title,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: cs.primary,
    );
  }
}
