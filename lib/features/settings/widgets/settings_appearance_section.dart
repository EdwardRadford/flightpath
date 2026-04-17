import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flight_path/shared/providers/accessibility_provider.dart';
import 'package:flight_path/shared/providers/theme_provider.dart';

// ---------------------------------------------------------------------------
// Appearance section (theme toggle)
// ---------------------------------------------------------------------------
class SettingsAppearanceSection extends ConsumerWidget {
  const SettingsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined,
                  color: cs.onSurface.withValues(alpha: 0.6), size: 20),
              const SizedBox(width: 10),
              Text(
                'Theme',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SettingsThemeOption(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: themeMode == ThemeMode.light,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 10),
              SettingsThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: themeMode == ThemeMode.dark,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark),
              ),
              const SizedBox(width: 10),
              SettingsThemeOption(
                label: 'System',
                icon: Icons.settings_brightness_rounded,
                isSelected: themeMode == ThemeMode.system,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsThemeOption({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.5),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accessibility section
// ---------------------------------------------------------------------------
class SettingsAccessibilitySection extends ConsumerWidget {
  const SettingsAccessibilitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessibility_new_rounded,
                  color: cs.onSurface.withValues(alpha: 0.6), size: 20),
              const SizedBox(width: 10),
              Text(
                'Display & Motion',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Larger Text',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            subtitle: Text(
              'Increases font sizes across the app for easier reading.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            value: settings.largerText,
            onChanged: (v) =>
                ref.read(accessibilityProvider.notifier).setLargerText(v),
            activeThumbColor: cs.primary,
          ),
          Divider(color: cs.outline, height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Reduce Animations',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            subtitle: Text(
              'Disables micro-animations and transitions throughout the app.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            value: settings.reduceAnimations,
            onChanged: (v) => ref
                .read(accessibilityProvider.notifier)
                .setReduceAnimations(v),
            activeThumbColor: cs.primary,
          ),
          Divider(color: cs.outline, height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'High Contrast',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            subtitle: Text(
              'Increases text contrast and border visibility for better readability.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            value: settings.highContrast,
            onChanged: (v) =>
                ref.read(accessibilityProvider.notifier).setHighContrast(v),
            activeThumbColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
