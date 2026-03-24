// Privacy Policy screen — inline GDPR-compliant privacy policy.
import 'package:flutter/material.dart';

/// Displays the Flight Path privacy policy inline (no external URL required).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _BodyText(
            'Last updated: March 2026\n\n'
            'Flight Path ("we", "us", "our") is operated by Ed Ward, England '
            'and Wales. This policy explains what personal data we collect, why '
            'we collect it, how it is used, and your rights under UK GDPR and '
            'the Data Protection Act 2018.',
            cs: cs,
          ),

          // ── 1. Data we collect ──────────────────────────────────────────
          _SectionHeader(label: '1. Data We Collect', cs: cs),
          _BulletList(
            items: const [
              'Account information: name, email address, and password (hashed by Firebase Auth).',
              'Profile information: aircraft type, total hours flown, current exercise number.',
              'Lesson data: scheduled and completed flight lesson records, including ratings, '
                  'quiz scores, instructor notes, personal reflections, weather data, and AI-generated debrief content.',
              'Exercise progress: per-exercise status, attempt count, best rating, and spaced-repetition due dates.',
              'Device token: Firebase Cloud Messaging (FCM) token for push notifications.',
              'Usage data: Firebase Analytics events (e.g. screen views, quiz completions). '
                  'Analytics data is aggregated and not linked to individual users beyond your Firebase UID.',
              'Crash reports: anonymised crash data via Firebase Crashlytics.',
            ],
            cs: cs,
          ),

          // ── 2. How we use your data ─────────────────────────────────────
          _SectionHeader(label: '2. How We Use Your Data', cs: cs),
          _BulletList(
            items: const [
              'To provide the app — storing and displaying your lesson history, '
                  'progress, and exercise content.',
              'AI coaching — your lesson data (ratings, notes, quiz score) is sent '
                  'to the Anthropic Claude API to generate personalised post-lesson feedback. '
                  'This data is not used to train Anthropic\'s models.',
              'Push notifications — lesson reminders, spaced-repetition prompts, '
                  'and inactivity nudges sent via FCM.',
              'Subscription management — your Firebase UID is shared with RevenueCat '
                  'to verify purchase status.',
              'Improving the app — aggregated, anonymised analytics and crash data '
                  'help us identify and fix bugs.',
            ],
            cs: cs,
          ),

          // ── 3. Legal basis ──────────────────────────────────────────────
          _SectionHeader(label: '3. Legal Basis for Processing', cs: cs),
          _BodyText(
            'We process your data on the basis of:\n\n'
            '• Contract — to deliver the services you have signed up for.\n'
            '• Legitimate interests — app analytics and crash reporting to '
            'maintain a reliable service.\n'
            '• Consent — push notifications (you may withdraw consent at any '
            'time via device settings or Settings → Notifications in the app).',
            cs: cs,
          ),

          // ── 4. Third-party processors ───────────────────────────────────
          _SectionHeader(label: '4. Third-Party Processors', cs: cs),
          _BodyText(
            'We share data with the following processors, each bound by their '
            'own data processing agreements:',
            cs: cs,
          ),
          _BulletList(
            items: const [
              'Google Firebase (Firebase Auth, Firestore, FCM, Analytics, Crashlytics) — '
                  'Google LLC, USA. Covered by Standard Contractual Clauses.',
              'RevenueCat — RevenueCat Inc., USA. Processes your Firebase UID and '
                  'purchase events only.',
              'Anthropic (Claude API) — Anthropic PBC, USA. Receives lesson data '
                  'for AI debrief generation. Data is not retained for model training.',
              'OpenWeatherMap — OpenWeather Ltd, UK. Receives GPS or manually entered '
                  'airfield ICAO codes for weather briefings.',
            ],
            cs: cs,
          ),

          // ── 5. Data retention ───────────────────────────────────────────
          _SectionHeader(label: '5. Data Retention', cs: cs),
          _BodyText(
            'Your data is retained for as long as your account is active. '
            'If you delete your account (Settings → Delete Account), all your '
            'data — including lessons, exercise progress, share links, messages, '
            'and your user profile — is permanently deleted from our systems '
            'within 30 days. Firebase Auth credentials are deleted immediately.',
            cs: cs,
          ),

          // ── 6. Your rights ──────────────────────────────────────────────
          _SectionHeader(label: '6. Your Rights', cs: cs),
          _BodyText(
            'Under UK GDPR you have the right to:',
            cs: cs,
          ),
          _BulletList(
            items: const [
              'Access — request a copy of the personal data we hold about you.',
              'Rectification — correct inaccurate data via Settings → Edit Profile.',
              'Erasure — delete your account and all associated data via '
                  'Settings → Delete Account.',
              'Portability — export your lesson data as a PDF via '
                  'Progress → Share Progress.',
              'Restriction — request that we restrict processing of your data '
                  'while a dispute is resolved.',
              'Object — object to processing based on legitimate interests.',
            ],
            cs: cs,
          ),
          _BodyText(
            'To exercise any right not available directly in the app, contact '
            'us at privacy@getflightpath.app. We will respond within 30 days.',
            cs: cs,
          ),

          // ── 7. Cookies and local storage ────────────────────────────────
          _SectionHeader(label: '7. Local Storage', cs: cs),
          _BodyText(
            'The app stores exercise content, offline lesson drafts, and '
            'notification preferences locally on your device using Hive and '
            'SharedPreferences. This data never leaves your device except as '
            'part of normal Firestore sync.',
            cs: cs,
          ),

          // ── 8. Children ─────────────────────────────────────────────────
          _SectionHeader(label: '8. Children', cs: cs),
          _BodyText(
            'Flight Path is not directed at children under 13. We do not '
            'knowingly collect personal data from children under 13. '
            'If you believe a child has provided us with personal data, '
            'please contact privacy@getflightpath.app.',
            cs: cs,
          ),

          // ── 9. Changes ──────────────────────────────────────────────────
          _SectionHeader(label: '9. Changes to This Policy', cs: cs),
          _BodyText(
            'We may update this policy from time to time. Material changes will '
            'be notified via the app\'s "What\'s New" section. Continued use of '
            'the app after changes constitutes acceptance of the updated policy.',
            cs: cs,
          ),

          // ── 10. Contact ─────────────────────────────────────────────────
          _SectionHeader(label: '10. Contact', cs: cs),
          _BodyText(
            'Data controller: Ed Ward\n'
            'Email: privacy@getflightpath.app\n\n'
            'If you have concerns about how we handle your data, you may also '
            'lodge a complaint with the Information Commissioner\'s Office (ICO) '
            'at ico.org.uk.',
            cs: cs,
          ),

          // ── 11. Governing law ───────────────────────────────────────────
          _SectionHeader(label: '11. Governing Law', cs: cs),
          _BodyText(
            'This policy is governed by the laws of England and Wales.',
            cs: cs,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Local helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme cs;

  const _SectionHeader({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _BodyText(this.text, {required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.75),
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final ColorScheme cs;

  const _BulletList({required this.items, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: CircleAvatar(
                        radius: 2.5,
                        backgroundColor:
                            cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.75),
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
