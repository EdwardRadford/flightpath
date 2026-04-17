import 'package:flutter/material.dart';
import 'package:flight_path/core/theme/app_theme.dart';

class PaywallBanner extends StatefulWidget {
  final VoidCallback? onShown;
  final int freeWindowStart;
  final int freeWindowEnd;

  const PaywallBanner({
    super.key,
    this.onShown,
    this.freeWindowStart = 1,
    this.freeWindowEnd = 3,
  });

  @override
  State<PaywallBanner> createState() => _PaywallBannerState();
}

class _PaywallBannerState extends State<PaywallBanner> {
  @override
  void initState() {
    super.initState();
    widget.onShown?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pro Exercise',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upgrade to Pro to unlock all 19 exercises.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
