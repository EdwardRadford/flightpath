// Privacy policy screen — static text display of the app's privacy policy.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

/// Displays the Flight Path privacy policy as static scrollable text.
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            'Last updated: January 2025',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Information We Collect',
            body:
                'Flight Path collects the information you provide when creating an account, '
                'including your name, email address, and training details such as your aircraft '
                'type, flight school, and home airfield. We also collect data about your '
                'exercise progress, lesson records, and quiz scores to power the app\'s '
                'personalised features.',
          ),
          _Section(
            title: 'How We Use Your Information',
            body:
                'We use your information to provide and improve the Flight Path service, '
                'personalise your training experience, send you relevant notifications, '
                'and generate AI-powered feedback on your progress. We do not sell your '
                'personal data to third parties.',
          ),
          _Section(
            title: 'Data Storage',
            body:
                'Your data is stored securely using Google Firebase, hosted in the EU.',
          ),
          _Section(
            title: 'AI Features',
            body:
                'Flight Path uses AI to provide debrief summaries and chat responses. '
                'Relevant exercise and progress data is sent to our Cloud Functions to '
                'generate these responses. This data is processed transiently and is '
                'not used to train AI models.',
          ),
          _Section(
            title: 'Notifications',
            body:
                'With your permission, Flight Path sends push notifications to remind '
                'you of upcoming lessons, prompt spaced repetition reviews, and nudge '
                'you if you have been inactive. You can manage or disable notifications '
                'at any time from Settings > Notification Preferences.',
          ),
          _Section(
            title: 'Account Deletion',
            body:
                'You may delete your account at any time from Settings > Delete Account. '
                'Deleting your account permanently removes your profile and all associated '
                'data from our servers. This action cannot be undone.',
          ),
          _Section(
            title: 'Cookies & Analytics',
            body:
                'Flight Path uses Firebase Analytics to understand how users interact '
                'with the app. This data is anonymised and aggregated. No advertising '
                'cookies are used.',
          ),
          _Section(
            title: 'Contact',
            body:
                'If you have questions about this privacy policy or how your data is '
                'handled, please contact us at privacy@flightpathapp.co.uk.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Flight Path is designed for student pilots training for the UK PPL. '
              'The app is intended as a study aid only and does not replace your '
              'instructor\'s guidance or official CAA documentation.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section widget
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
