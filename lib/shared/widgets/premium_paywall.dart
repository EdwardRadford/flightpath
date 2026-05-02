// Premium paywall bottom sheet — shown when a free user tries to access
// exercises 5+ or premium features (AI debrief, full progress tracking).
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/shared/services/subscription_service.dart';
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
}) async {
  FirebaseAnalytics.instance.logEvent(
    name: 'paywall_shown',
    parameters: {
      if (source != null) 'source': source,
    },
  );
  final purchased = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => PremiumPaywallSheet(
          freeWindowStart: freeWindowStart,
          freeWindowEnd: freeWindowEnd,
        ),
      ) ??
      false;

  if (purchased) {
    // Show a success confirmation. The RevenueCat webhook updates isPremium
    // async — this snackbar bridges the gap while the stream catches up.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Welcome to Pro. All exercises and AI features are now unlocked.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } else {
    FirebaseAnalytics.instance.logEvent(
      name: 'paywall_dismissed',
      parameters: {
        if (source != null) 'source': source,
      },
    );
  }
  return purchased;
}

class PremiumPaywallSheet extends StatefulWidget {
  final int freeWindowStart;
  final int freeWindowEnd;

  const PremiumPaywallSheet({
    super.key,
    this.freeWindowStart = 1,
    this.freeWindowEnd = 3,
  });

  @override
  State<PremiumPaywallSheet> createState() => _PremiumPaywallSheetState();
}

class _PremiumPaywallSheetState extends State<PremiumPaywallSheet> {
  bool _loading = false;

  Future<void> _purchase() async {
    FirebaseAnalytics.instance.logEvent(name: 'upgrade_tapped');
    setState(() => _loading = true);
    final success = await SubscriptionService.purchaseLifetime();

    if (success) {
      FirebaseAnalytics.instance.logEvent(name: 'premium_purchased');
      FirebaseAnalytics.instance.logEvent(name: 'subscription_started');
      FirebaseAnalytics.instance.logEvent(name: 'purchase_completed');
      // Premium fields (has_purchased, subscription_status) are written
      // exclusively by the RevenueCat webhook Cloud Function. The
      // appUserProvider stream will reflect the updated status once the
      // webhook fires. Do NOT write them here — that would bypass the
      // server-side validation and create a paywall bypass vector.
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase not completed. Tap the button to try again.'),
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
        const SnackBar(
          content: Text('No previous purchase found.'),
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
              'Unlock Flight Path Training Pro',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
             Text(
              '\u00A3${AppConstants.premiumPriceGbp.toStringAsFixed(0)} \u2014 one payment, no subscription.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
             Text(
              'Less than the cost of a single flying lesson.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Feature list
            _FeatureRow(icon: Icons.auto_awesome_rounded, text: 'AI debrief after every lesson \u2014 know what to fix before you fly again'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.style_rounded, text: 'Spaced repetition flashcards \u2014 stop forgetting between lessons'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.track_changes_rounded, text: 'Full progress tracking across all 19 exercises'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.psychology_rounded, text: 'Ask the AI tutor anything, any time'),
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
                        'Get lifetime access \u2014 \u00A3${AppConstants.premiumPriceGbp.toStringAsFixed(0)}',
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
