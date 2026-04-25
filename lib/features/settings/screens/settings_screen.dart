// Settings screen — profile summary, appearance, notifications, legal, privacy, sign out, and account deletion.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/walkthrough_provider.dart';
import 'package:flight_path/features/home/screens/home_screen.dart';
import 'package:flight_path/features/settings/widgets/settings_section_header.dart';
import 'package:flight_path/features/settings/widgets/settings_profile_section.dart';
import 'package:flight_path/features/settings/widgets/settings_appearance_section.dart';
import 'package:flight_path/features/settings/widgets/settings_subscription_section.dart';
import 'package:flight_path/features/settings/widgets/settings_legal_privacy.dart';
import 'package:flight_path/features/settings/widgets/settings_account_buttons.dart';
import 'package:flight_path/shared/widgets/app_tour_dialog.dart';

// ---------------------------------------------------------------------------
// SettingsScreen
// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'settings_opened');
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
              // ── Profile ───────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Profile'),
              SettingsProfileSection(user: user),
              const SizedBox(height: 20),

              // ── Aircraft & Training ───────────────────────────────────────
              const SettingsSectionHeader(label: 'Aircraft & Training'),
              SettingsAircraftSection(user: user),
              const SizedBox(height: 20),

              // ── Progress ──────────────────────────────────────────────────
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

              // ── Appearance ────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Appearance'),
              const SettingsAppearanceSection(),
              const SizedBox(height: 20),

              // ── Accessibility ──────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Accessibility'),
              const SettingsAccessibilitySection(),
              const SizedBox(height: 20),

              // ── Notifications ─────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Notifications'),
              const SettingsNotificationsSection(),
              const SizedBox(height: 20),

              // ── Purchase (free users only) ────────────────────────────────
              if (!(user?.isPremium ?? false)) ...[
                const SettingsSectionHeader(label: 'Purchase'),
                SettingsSubscriptionSection(user: user),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 0),

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
              const SizedBox(height: 20),

              // ── Offline ─────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Offline'),
              const SettingsOfflineDownloadTile(),
              const SizedBox(height: 20),

              // ── Safety Disclaimer ─────────────────────────────────────────
              const SettingsSectionHeader(label: 'Safety Disclaimer'),
              const SettingsDisclaimerSection(),
              const SizedBox(height: 20),

              // ── Legal ──────────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Legal'),
              const SettingsLegalSection(),
              const SizedBox(height: 20),

              // ── Privacy ─────────────────────────────────────────────────
              const SettingsSectionHeader(label: 'Privacy'),
              SettingsPrivacySection(uid: user?.uid ?? ''),
              const SizedBox(height: 20),

              // ── Sign Out ──────────────────────────────────────────────────
              const SettingsSignOutButton(),
              const SizedBox(height: 12),

              // ── Delete Account ────────────────────────────────────────────
              const SettingsDeleteAccountButton(),
              const SizedBox(height: 32),

              // ── App version ───────────────────────────────────────────────
              Center(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '';
                    return Text(
                      version.isNotEmpty
                          ? 'Flight Path v$version'
                          : 'Flight Path',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
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
