// Milestone celebration screen — shown after first solo or full syllabus completion; offers a share sheet and returns to home.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flight_path/core/theme/app_theme.dart';

class MilestoneCelebrationScreen extends StatelessWidget {
  final bool isFirstSolo;

  const MilestoneCelebrationScreen({
    super.key,
    required this.isFirstSolo,
  });

  @override
  Widget build(BuildContext context) {
    final title = isFirstSolo ? 'First Solo' : 'Syllabus Complete';
    final message = isFirstSolo
        ? "You've passed the most significant milestone in your training. Time to solo the skies."
        : "You've worked through all 19 PPL exercises. The examiner awaits.";
    final icon =
        isFirstSolo ? Icons.flight_rounded : Icons.workspace_premium_rounded;
    final shareText = isFirstSolo
        ? "I just completed my first solo flight! Studying for my PPL with Flight Path Training: https://getflightpath.app"
        : "I've completed the full UK PPL syllabus with Flight Path Training: https://getflightpath.app";

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              Icon(
                icon,
                color: AppColors.primary,
                size: 72,
              ),
              const SizedBox(height: 32),

              Text(
                title,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                message,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(text: shareText));
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text(
                    'Share',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Screen can be pushed from multiple entry points; fall back
                    // to /home if there is nothing to pop (e.g. deep-link entry).
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
