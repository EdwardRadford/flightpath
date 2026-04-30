// CAP 413 Mandatory Readback reference screen — reached from the Learn tab.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/learn/data/readback_data.dart';

class MandatoryReadbackScreen extends StatelessWidget {
  const MandatoryReadbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final surfaceColor = cs.surface;
    final onSurface = cs.onSurface;
    final onSurfaceVariant =
        isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mandatory Readbacks'),
            Text(
              'CAP 413 — Chapter 3',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: onSurfaceVariant,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ...kMandatoryReadbacks.map(
            (section) => _SectionCard(
              section: section,
              surfaceColor: surfaceColor,
              dividerColor: dividerColor,
              onSurface: onSurface,
              onSurfaceVariant: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Source: CAP 413 v24 (April 2026). Always verify against the current edition.',
            style: TextStyle(
              fontSize: 12,
              color: onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.surfaceColor,
    required this.dividerColor,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  final ReadbackSection section;
  final Color surfaceColor;
  final Color dividerColor;
  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dividerColor, width: 0.75),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.category,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 10),
            ...section.items.map(
              (item) => _BulletRow(
                text: item,
                onSurface: onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text, required this.onSurface});

  final String text;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
