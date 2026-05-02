// Soft upsell dialog shown to free users at moments where Pro adds clear
// value (e.g. after saving a lesson, before they enter the AI debrief). This
// is intentionally lighter-weight than [PremiumPaywallSheet] — a single nudge
// with two outcomes: open the full paywall, or proceed with the limited free
// experience.
import 'package:flutter/material.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

/// Shows the soft upsell dialog. Returns when the dialog is dismissed —
/// the upgrade flow is launched internally if the user taps the primary
/// button, then the dialog closes either way.
Future<void> showPremiumUpsellCard(
  BuildContext context, {
  required String title,
  required String message,
  required String primaryLabel,
  required String secondaryLabel,
  required String paywallSource,
  int freeWindowStart = 1,
  int freeWindowEnd = 3,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PremiumUpsellCard(
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
      paywallSource: paywallSource,
      freeWindowStart: freeWindowStart,
      freeWindowEnd: freeWindowEnd,
    ),
  );
}

class PremiumUpsellCard extends StatelessWidget {
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final String paywallSource;
  final int freeWindowStart;
  final int freeWindowEnd;

  const PremiumUpsellCard({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.paywallSource,
    this.freeWindowStart = 1,
    this.freeWindowEnd = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await showPremiumPaywall(
                  context,
                  source: paywallSource,
                  freeWindowStart: freeWindowStart,
                  freeWindowEnd: freeWindowEnd,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '$primaryLabel £${AppConstants.premiumPriceGbp.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
