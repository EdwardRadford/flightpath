import 'package:flutter/material.dart';
import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

class SettingsSubscriptionSection extends StatelessWidget {
  final AppUser? user;

  const SettingsSubscriptionSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPremium = user?.isPremium ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium) ...[
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Pro',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'You have Pro access to all exercises and features.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            if (user?.purchaseDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Purchased ${_formatDate(user!.purchaseDate!)}',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            Text(
              'Free Plan',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Free access covers your current exercise \u00B12 either side. Upgrade to Pro to unlock all 19 exercises and AI debriefs.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showPremiumPaywall(
                    context,
                    source: 'settings',
                    freeWindowStart: user?.freeWindowStart ?? 1,
                    freeWindowEnd: user?.freeWindowEnd ?? 3,
                  );
                },
                child: Text(
                  'Upgrade to Pro \u2014 \u00A3${AppConstants.premiumPriceGbp.toStringAsFixed(2)}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () async {
                  final success = await showPremiumPaywall(
                    context,
                    source: 'settings_restore',
                    freeWindowStart: user?.freeWindowStart ?? 1,
                    freeWindowEnd: user?.freeWindowEnd ?? 3,
                  );
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase restored successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: Text(
                  'Restore purchase',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
