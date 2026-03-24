// Premium paywall bottom sheet — shown when a free user tries to access
// exercises 5+ or premium features (AI debrief, instructor sharing).
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/services/subscription_service.dart';
import 'package:flight_path/core/theme/app_theme.dart';

/// Shows the premium upgrade bottom sheet. Returns `true` if the purchase
/// succeeded, `false` otherwise.
///
/// [freeWindowStart] and [freeWindowEnd] define the user's personalised free
/// exercise window so the paywall can display a contextual message.
Future<bool> showPremiumPaywall(
  BuildContext context, {
  String? source,
  int freeWindowStart = 1,
  int freeWindowEnd = 3,
}) {
  FirebaseAnalytics.instance.logEvent(
    name: 'paywall_shown',
    parameters: {
      'source': ?source,
    },
  );
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PremiumPaywallSheet(
      freeWindowStart: freeWindowStart,
      freeWindowEnd: freeWindowEnd,
    ),
  ).then((v) {
    final purchased = v ?? false;
    if (!purchased) {
      FirebaseAnalytics.instance.logEvent(
        name: 'paywall_dismissed',
        parameters: {
          'source': ?source,
        },
      );
    }
    return purchased;
  });
}

class _PremiumPaywallSheet extends StatefulWidget {
  final int freeWindowStart;
  final int freeWindowEnd;

  const _PremiumPaywallSheet({
    required this.freeWindowStart,
    required this.freeWindowEnd,
  });

  @override
  State<_PremiumPaywallSheet> createState() => _PremiumPaywallSheetState();
}

class _PremiumPaywallSheetState extends State<_PremiumPaywallSheet> {
  bool _loading = false;

  Future<void> _purchase() async {
    setState(() => _loading = true);
    final success = await SubscriptionService.purchaseLifetime();
    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      FirebaseAnalytics.instance.logEvent(name: 'premium_purchased');
      FirebaseAnalytics.instance.logEvent(name: 'subscription_started');
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Purchase cancelled or unavailable.'),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    final success = await SubscriptionService.restorePurchases();
    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      FirebaseAnalytics.instance.logEvent(name: 'premium_restored');
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('No previous purchase found.'),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // Title
             Text(
              'Unlock All 19 Exercises',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
             Text(
              'You have free access to exercises ${widget.freeWindowStart} to ${widget.freeWindowEnd}. '
              'Unlock all 19 exercises with a one-time purchase.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Feature list
            _FeatureRow(icon: Icons.school_rounded, text: 'All 19 CAA exercises with briefs & quizzes'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.auto_awesome_rounded, text: 'AI-powered lesson debriefs'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.cloud_rounded, text: 'Weather briefings for your airfield'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.share_rounded, text: 'Share progress with your instructor'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.all_inclusive_rounded, text: 'One-time payment \u2014 no subscription'),
            const SizedBox(height: 28),

            // Purchase button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Upgrade to Pro \u2014 \u00A3${AppConstants.premiumPriceGbp.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Restore
            TextButton(
              onPressed: _loading ? null : _restore,
              child:  Text(
                'Restore Purchase',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
