// Settings screen — profile summary, appearance, notifications, legal, privacy, sign out, and account deletion.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/providers/walkthrough_provider.dart';
import 'package:flight_path/shared/services/subscription_service.dart';
import 'package:flight_path/features/settings/widgets/settings_section_header.dart';
import 'package:flight_path/features/settings/widgets/settings_profile_section.dart';
import 'package:flight_path/features/settings/widgets/settings_appearance_section.dart';
import 'package:flight_path/features/settings/widgets/settings_subscription_section.dart';
import 'package:flight_path/features/settings/widgets/settings_legal_privacy.dart';
import 'package:flight_path/features/settings/widgets/settings_account_buttons.dart';
import 'package:flight_path/shared/widgets/app_tour_dialog.dart';

// ---------------------------------------------------------------------------
// _GroupHeader — top-level section divider for the 4 setting groups
// ---------------------------------------------------------------------------
class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Bumped from fontSize 10 / alpha 0.35 to 11 / alpha 0.7 — earlier
    // combination failed WCAG AA contrast (≈ 2.6:1).
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SettingsScreen
// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _restoringPurchases = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'settings_opened');
  }

  Future<void> _restorePurchases() async {
    if (_restoringPurchases) return;
    setState(() => _restoringPurchases = true);
    try {
      final hasEntitlement = await SubscriptionService.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasEntitlement ? 'Purchases restored' : 'Nothing to restore',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore failed — please try again'),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoringPurchases = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: userAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
        error: (_, __) => Center(
          child: Text('Unable to load settings. Please try again.',
              style: TextStyle(color: cs.error)),
        ),
        data: (user) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── ACCOUNT ───────────────────────────────────────────────────
              const _GroupHeader(label: 'Account'),
              const SizedBox(height: 10),

              const SettingsSectionHeader(label: 'Profile'),
              SettingsProfileSection(user: user),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Aircraft & Training'),
              SettingsAircraftSection(user: user),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Purchases'),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: _restorePurchases,
                  leading: _restoringPurchases
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        )
                      : Icon(Icons.restore_rounded,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                  title: Text(
                    'Restore Purchases',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Reinstate a previous lifetime purchase',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── APP ───────────────────────────────────────────────────────
              const _GroupHeader(label: 'App'),
              const SizedBox(height: 10),

              const SettingsSectionHeader(label: 'Appearance'),
              const SettingsAppearanceSection(),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Accessibility'),
              const SettingsAccessibilitySection(),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Notifications'),
              const SettingsNotificationsSection(),
              const SizedBox(height: 20),

              if (!(ref.watch(premiumStatusProvider).valueOrNull ?? false)) ...[
                const SettingsSectionHeader(label: 'Purchase'),
                SettingsSubscriptionSection(user: user),
                const SizedBox(height: 20),
              ],


              // ── Help ──────────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Help'),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => context.push('/settings/bug-report'),
                  leading: Icon(Icons.bug_report_outlined,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  title: Text(
                    'Report a problem',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    "Let us know if something isn't working",
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Reference ─────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Reference'),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => context.push('/whats-new'),
                      leading: Icon(Icons.new_releases_outlined,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      title: Text(
                        "What's New",
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'See the latest updates and features',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    Divider(color: cs.outline, height: 1, indent: 56),
                    ListTile(
                      onTap: () async {
                        await ref
                            .read(walkthroughNotifierProvider.notifier)
                            .reset();
                        if (!context.mounted) return;
                        await showAppTourDialog(context);
                        if (!context.mounted) return;
                        await ref
                            .read(walkthroughNotifierProvider.notifier)
                            .markComplete();
                      },
                      leading: Icon(Icons.tour_outlined,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      title: Text(
                        'Replay App Tour',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'See the feature walkthrough again',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── TRAINING ──────────────────────────────────────────────────
              const _GroupHeader(label: 'Training'),
              const SizedBox(height: 10),

              const SettingsSectionHeader(label: 'Training Progress'),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => context.go('/progress'),
                  leading: Icon(Icons.bar_chart_rounded,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  title: Text(
                    'View Progress',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Exercise progress, hours, and syllabus overview',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Offline Download'),
              const SettingsOfflineDownloadTile(),
              const SizedBox(height: 28),

              // ── LEGAL & SUPPORT ───────────────────────────────────────────
              const _GroupHeader(label: 'Legal & Support'),
              const SizedBox(height: 10),

              const SettingsSectionHeader(label: 'Safety Disclaimer'),
              const SettingsDisclaimerSection(),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Legal'),
              const SettingsLegalSection(),
              const SizedBox(height: 20),

              const SettingsSectionHeader(label: 'Privacy'),
              const SettingsConsentSection(),
              const SizedBox(height: 12),
              SettingsPrivacySection(uid: user?.uid ?? ''),
              const SizedBox(height: 20),

              const SettingsSignOutButton(),
              const SizedBox(height: 12),

              const SettingsDeleteAccountButton(),
              const SizedBox(height: 24),

              Center(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '';
                    return Text(
                      version.isNotEmpty
                          ? 'Flight Path Training v$version'
                          : 'Flight Path Training',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
