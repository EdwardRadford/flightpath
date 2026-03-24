// Reusable empty-state placeholder used across multiple screens.
// Uses an instrument bezel gradient for the icon background.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/widgets/aviation_widgets.dart';

/// A consistent empty-state widget showing a large icon with instrument bezel,
/// headline, subtitle, and an optional CTA button.
class EmptyStateWidget extends StatelessWidget {
  /// Material icon displayed prominently at the top.
  final IconData icon;

  /// Bold headline text (1 line).
  final String title;

  /// Supportive description shown below the headline.
  final String subtitle;

  /// Optional button label. When provided along with [onButtonPressed],
  /// a CTA button is rendered below the subtitle.
  final String? buttonText;

  /// Callback for the optional CTA button.
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large icon with instrument bezel gradient
            InstrumentBezelIcon(icon: icon, size: 88),
            const SizedBox(height: 28),

            // Headline
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Optional CTA button
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBright,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonText!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
