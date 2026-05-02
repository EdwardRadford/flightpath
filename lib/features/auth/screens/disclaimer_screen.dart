// Safety disclaimer screen — must be acknowledged before using the app.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';

/// Presents the safety notice and requires scroll-to-bottom + checkbox acknowledgement.
class DisclaimerScreen extends ConsumerStatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  ConsumerState<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends ConsumerState<DisclaimerScreen> {
  bool _acknowledged = false;
  bool _loading = false;
  bool _hasScrolledToBottom = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasScrolledToBottom) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  Future<void> _accept() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'disclaimer_acknowledged': true,
      });
      FirebaseAnalytics.instance.logEvent(name: 'disclaimer_accepted');
      // Router automatically navigates to /home via stream update
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save — please try again. ($e)'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Safety Notice',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(
                          title: 'Study aid only',
                          body:
                              'Flight Path Training is a study companion designed to help you prepare for and reflect on your flying lessons. It is not a replacement for instruction from a qualified flying instructor (FI).',
                        ),
                        _Section(
                          title: 'Always follow your instructor',
                          body:
                              'All decisions during flight must follow the guidance of your instructor and comply with UK CAA regulations and Air Navigation Order requirements. This app does not provide operational flight guidance.',
                        ),
                        _Section(
                          title: 'Never use during flight',
                          body:
                              'Do not use this app while airborne or during any phase of flight, including taxiing. Your full attention must remain outside the aircraft during all operations.',
                        ),
                        _Section(
                          title: 'Content accuracy',
                          body:
                              'While content is based on CAP 1298, it is for educational reference only. Always refer to current official CAA publications for authoritative information.',
                        ),
                        _Section(
                          title: 'Weather information',
                          body:
                              'Any weather data shown is for general awareness only and must not be used for flight planning. Always obtain a proper aviation weather briefing from official sources (Met Office, ATIS, etc.).',
                        ),
                        _Section(
                          title: 'AI-generated content',
                          body:
                              'Post-lesson debrief summaries are generated by AI and may contain inaccuracies. They are for reflection purposes only. Discuss all aspects of your training with your instructor.',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'By continuing, you acknowledge that Flight Path Training is a training aid and accept full responsibility for your own safety and compliance with applicable regulations.',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            // Bumped from 12pt italic to 14pt regular — the
                            // acceptance phrasing should not be the smallest
                            // text on the safety notice.
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _hasScrolledToBottom
                    ? () => setState(() => _acknowledged = !_acknowledged)
                    : null,
                child: Row(
                  children: [
                    Checkbox(
                      value: _acknowledged,
                      onChanged: _hasScrolledToBottom
                          ? (v) => setState(() => _acknowledged = v ?? false)
                          : null,
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasScrolledToBottom
                            ? 'I have read and understood this safety notice'
                            : 'Please read the full notice above to continue',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: _hasScrolledToBottom
                                  ? null
                                  : AppColors.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_acknowledged && !_loading) ? _accept : null,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue to Flight Path Training'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
