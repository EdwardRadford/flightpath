// What's New screen — shows version history and recent changes.
import 'package:flutter/material.dart';

import 'package:flight_path/core/constants/whats_new_data.dart';
import 'package:flight_path/core/theme/app_theme.dart';

/// Displays all version entries in reverse chronological order.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("What's New"),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: whatsNewEntries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final entry = whatsNewEntries[index];
          return _VersionCard(entry: entry);
        },
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final WhatsNewEntry entry;

  const _VersionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'v${entry.version}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Date
          Text(
            entry.date,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Changes
          ...entry.changes.map((change) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        change,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
