import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/consent_service.dart';

// ---------------------------------------------------------------------------
// Safety disclaimer section
// ---------------------------------------------------------------------------
class SettingsDisclaimerSection extends StatelessWidget {
  static const String _shortText =
      'Flight Path Training is a study aid only. It does not replace official flight '
      'training, your instructor\'s guidance, or official CAA publications. '
      'Never use this app in flight.';

  static const String _fullText =
      'Flight Path Training is a study aid only. It does not replace official flight '
      'training, your instructor\'s guidance, or official CAA publications. '
      'Never use this app in flight. Always conduct a full pre-flight briefing '
      'with your instructor.\n\n'
      'The information contained within this app is for educational and '
      'reference purposes only. Flight operations involve risk. Always follow '
      'your instructor\'s advice, current NOTAMs, and official CAA guidance. '
      'The app\'s AI-generated content is not a substitute for professional '
      'flight instruction.';

  const SettingsDisclaimerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
              SizedBox(width: 8),
              Text(
                'Safety Notice',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _shortText,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'View Full Disclaimer',
            button: true,
            child: GestureDetector(
              onTap: () => _showFullDisclaimer(context),
              child: Text(
                'View Full Disclaimer',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullDisclaimer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Safety Disclaimer',
          style: TextStyle(color: cs.onSurface),
        ),
        content: SingleChildScrollView(
          child: Text(
            _fullText,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal section
// ---------------------------------------------------------------------------
class SettingsLegalSection extends StatelessWidget {
  const SettingsLegalSection({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please try again later.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.privacy_tip_outlined,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'Privacy Policy',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            trailing: Icon(
              Icons.open_in_new,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            onTap: () =>
                _openUrl(context, 'https://getflightpath.app/privacy'),
          ),
          Divider(color: cs.outline, height: 1, indent: 56),
          ListTile(
            leading: Icon(
              Icons.description_outlined,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'Terms of Service',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            trailing: Icon(
              Icons.open_in_new,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            onTap: () =>
                _openUrl(context, 'https://getflightpath.app/terms'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy section (GDPR data export)
// ---------------------------------------------------------------------------
class SettingsPrivacySection extends StatefulWidget {
  final String uid;

  const SettingsPrivacySection({super.key, required this.uid});

  @override
  State<SettingsPrivacySection> createState() => _SettingsPrivacySectionState();
}

class _SettingsPrivacySectionState extends State<SettingsPrivacySection> {
  bool _exporting = false;

  Future<void> _exportData() async {
    if (_exporting || widget.uid.isEmpty) return;
    setState(() => _exporting = true);

    try {
      FirebaseAnalytics.instance.logEvent(name: 'data_export_started');
      final uri = Uri.parse(
        'mailto:contact@getflightpath.app'
        '?subject=Flight%20Path%20Training%20data%20export%20request'
        '&body=Hi,%0A%0AI%20would%20like%20to%20request%20a%20copy%20of%20my%20data.%0A%0A'
        'Account%20UID:%20${widget.uid}%0A%0AThank%20you.',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch email client');
      }
      FirebaseAnalytics.instance.logEvent(name: 'data_export_completed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Email contact@getflightpath.app to request your data.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
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
        onTap: _exporting ? null : _exportData,
        leading: _exporting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.download_rounded,
                color: cs.onSurface.withValues(alpha: 0.6)),
        title: Text(
          _exporting ? 'Opening email\u2026' : 'Request Data Export',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Email us at contact@getflightpath.app to request a copy of your data',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: _exporting
            ? null
            : Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consent section — analytics / crashlytics / push notifications
// ---------------------------------------------------------------------------

/// Three independent toggles for the optional services gated by user consent.
/// Tapping a toggle re-runs the activate / deactivate call immediately so the
/// state of the underlying SDK matches the persisted preference.
class SettingsConsentSection extends StatefulWidget {
  const SettingsConsentSection({super.key});

  @override
  State<SettingsConsentSection> createState() => _SettingsConsentSectionState();
}

class _SettingsConsentSectionState extends State<SettingsConsentSection> {
  bool _loading = true;
  bool _analytics = false;
  bool _crashlytics = false;
  bool _notifications = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final analytics = await ConsentService.isGranted(ConsentKeys.analytics);
    final crash = await ConsentService.isGranted(ConsentKeys.crashlytics);
    final notif =
        await ConsentService.isGranted(ConsentKeys.notifications);
    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _crashlytics = crash;
      _notifications = notif;
      _loading = false;
    });
  }

  Future<void> _setConsent(String key, bool value) async {
    setState(() {
      if (key == ConsentKeys.analytics) _analytics = value;
      if (key == ConsentKeys.crashlytics) _crashlytics = value;
      if (key == ConsentKeys.notifications) _notifications = value;
    });
    await ConsentService.setConsent(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _crashlytics,
            onChanged: (v) => _setConsent(ConsentKeys.crashlytics, v),
            activeColor: AppColors.primary,
            title: Text(
              'Crash reports',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            subtitle: Text(
              'Help us fix bugs you hit',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          Divider(color: cs.outline, height: 1, indent: 16),
          SwitchListTile(
            value: _analytics,
            onChanged: (v) => _setConsent(ConsentKeys.analytics, v),
            activeColor: AppColors.primary,
            title: Text(
              'Analytics',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            subtitle: Text(
              'Help us understand which features you use most',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          Divider(color: cs.outline, height: 1, indent: 16),
          SwitchListTile(
            value: _notifications,
            onChanged: (v) => _setConsent(ConsentKeys.notifications, v),
            activeColor: AppColors.primary,
            title: Text(
              'Push notifications',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            subtitle: Text(
              'Reminders to revise and lesson alerts',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
