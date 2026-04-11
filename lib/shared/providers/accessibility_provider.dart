// Accessibility preferences provider — persists user accessibility settings
// (larger text, reduce animations, high contrast) to SharedPreferences and
// exposes them via Riverpod for use throughout the app.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── SharedPreferences keys ──────────────────────────────────────────────────
const String _kLargerText = 'accessibility_larger_text';
const String _kReduceAnimations = 'accessibility_reduce_animations';
const String _kHighContrast = 'accessibility_high_contrast';

/// Immutable data class holding all accessibility preferences.
@immutable
class AccessibilitySettings {
  /// When true, increase base font sizes by 2sp across the app.
  final bool largerText;

  /// When true, disable micro-animations and transitions.
  final bool reduceAnimations;

  /// When true, increase text contrast and border visibility.
  final bool highContrast;

  const AccessibilitySettings({
    this.largerText = false,
    this.reduceAnimations = false,
    this.highContrast = false,
  });

  AccessibilitySettings copyWith({
    bool? largerText,
    bool? reduceAnimations,
    bool? highContrast,
  }) {
    return AccessibilitySettings(
      largerText: largerText ?? this.largerText,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  /// The extra font size delta to apply when [largerText] is enabled.
  double get fontSizeDelta => largerText ? 2.0 : 0.0;
}

/// Riverpod provider for accessibility settings.
final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>((ref) {
  return AccessibilityNotifier();
});

/// Persists and exposes the user's accessibility preferences.
class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(const AccessibilitySettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AccessibilitySettings(
      largerText: prefs.getBool(_kLargerText) ?? false,
      reduceAnimations: prefs.getBool(_kReduceAnimations) ?? false,
      highContrast: prefs.getBool(_kHighContrast) ?? false,
    );
  }

  Future<void> setLargerText(bool value) async {
    state = state.copyWith(largerText: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLargerText, value);
  }

  Future<void> setReduceAnimations(bool value) async {
    state = state.copyWith(reduceAnimations: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReduceAnimations, value);
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighContrast, value);
  }
}
