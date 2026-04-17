import 'package:flutter/material.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String label;

  const SettingsSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
