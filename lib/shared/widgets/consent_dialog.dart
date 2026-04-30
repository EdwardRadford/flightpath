// Consent dialog — shown once, after the safety disclaimer is acknowledged.
// Lets the user opt in to Analytics, Crashlytics, and FCM push notifications.
// All three default to off. Users can change their choices any time from
// Settings -> Privacy.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/consent_service.dart';

/// Shows the first-launch consent dialog. Not dismissable by tapping outside.
/// Returns when the user has either pressed Save or Skip — both routes mark
/// the dialog as prompted so it does not re-appear next launch.
Future<void> showConsentDialog(BuildContext context) async {
  // If we have already prompted the user once, don't show it again.
  if (await ConsentService.hasBeenPrompted()) return;

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ConsentDialog(),
  );

  await ConsentService.markPrompted();
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog();

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  // Default to opt-out — UK GDPR + PECR require explicit consent for
  // non-essential analytics + tracking.
  bool _analytics = false;
  bool _crashlytics = false;
  bool _notifications = false;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ConsentService.setConsent(ConsentKeys.analytics, _analytics);
      await ConsentService.setConsent(ConsentKeys.crashlytics, _crashlytics);
      await ConsentService.setConsent(
        ConsentKeys.notifications,
        _notifications,
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _skip() async {
    if (_saving) return;
    // Skip == leave everything off. Persist explicit `false` so we don't
    // hit the SDK defaults (which silently re-enable Analytics/Crashlytics).
    setState(() => _saving = true);
    try {
      await ConsentService.setConsent(ConsentKeys.analytics, false);
      await ConsentService.setConsent(ConsentKeys.crashlytics, false);
      await ConsentService.setConsent(ConsentKeys.notifications, false);
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        'Optional services',
        style: TextStyle(color: cs.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Flight Path uses three optional services to improve the app. '
              'You can change these any time in Settings → Privacy.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            _ConsentTile(
              title: 'Crash reports',
              description: 'Help us fix bugs you hit.',
              value: _crashlytics,
              enabled: !_saving,
              onChanged: (v) => setState(() => _crashlytics = v),
            ),
            _ConsentTile(
              title: 'Analytics',
              description:
                  'Help us understand which features you use most.',
              value: _analytics,
              enabled: !_saving,
              onChanged: (v) => setState(() => _analytics = v),
            ),
            _ConsentTile(
              title: 'Push notifications',
              description:
                  'Reminders to revise and lesson alerts.',
              value: _notifications,
              enabled: !_saving,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _skip,
          child: Text(
            'Skip',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ConsentTile({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
