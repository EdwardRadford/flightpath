// Settings screen — profile summary, appearance, notifications, instructor
// linking, legal, privacy, sign out, and account deletion.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/services/auth_service.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/providers/accessibility_provider.dart';
import 'package:flight_path/shared/providers/theme_provider.dart';
import 'package:flight_path/shared/providers/walkthrough_provider.dart';
import 'package:flight_path/shared/services/content_cache_service.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';
import 'package:flight_path/features/home/screens/home_screen.dart';

// ---------------------------------------------------------------------------
// Aircraft type human-readable labels
// ---------------------------------------------------------------------------
String _aircraftLabel(String type) =>
    AppConstants.aircraftTypes[type] ?? (type.isNotEmpty ? type : 'Not set');

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
              const _SectionHeader(label: 'Profile'),
              _ProfileSection(user: user),
              const SizedBox(height: 20),

              // ── Aircraft & Training ───────────────────────────────────────
              const _SectionHeader(label: 'Aircraft & Training'),
              _AircraftSection(user: user),
              const SizedBox(height: 20),

              // ── Progress ──────────────────────────────────────────────────
              const _SectionHeader(label: 'Training Progress'),
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
              const _SectionHeader(label: 'Appearance'),
              const _AppearanceSection(),
              const SizedBox(height: 20),

              // ── Accessibility ──────────────────────────────────────────────
              const _SectionHeader(label: 'Accessibility'),
              const _AccessibilitySection(),
              const SizedBox(height: 20),

              // ── Notifications ─────────────────────────────────────────────
              const _SectionHeader(label: 'Notifications'),
              const _NotificationsSection(),
              const SizedBox(height: 20),

              // ── Purchase (free users only) ────────────────────────────────
              if (!(user?.isPremium ?? false)) ...[
                const _SectionHeader(label: 'Purchase'),
                _SubscriptionSection(user: user),
                const SizedBox(height: 20),
              ],

              // ── Instructor Sharing / Linking ─────────────────────────────
              if (user?.isInstructor == true) ...[
                const _SectionHeader(label: 'Instructor'),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () =>
                            context.push('/instructor/invite-code'),
                        leading: Icon(Icons.qr_code_rounded,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                        title: Text(
                          'My Invite Code',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Share this code with your students',
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
                        onTap: () => context.go('/instructor'),
                        leading: Icon(Icons.dashboard_rounded,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                        title: Text(
                          'Instructor Dashboard',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'View and manage your students',
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
              ] else ...[
                const _SectionHeader(label: 'Instructor'),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => context.push('/link-instructor'),
                        leading: Icon(Icons.person_add_rounded,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                        title: Text(
                          'Link Instructor',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Enter your instructor\'s invite code',
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
              ],
              const SizedBox(height: 20),

              // ── Reference ─────────────────────────────────────────────────
              const _SectionHeader(label: 'Reference'),
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
                    if (user?.isInstructor != true) ...[
                      Divider(color: cs.outline, height: 1, indent: 56),
                      ListTile(
                        onTap: () {
                          ref
                              .read(walkthroughNotifierProvider.notifier)
                              .reset();
                          // Reset the static session guard so the tour re-triggers
                          HomeScreen.resetWalkthroughGuard();
                          context.go('/home');
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Offline ─────────────────────────────────────────────────
              const _SectionHeader(label: 'Offline'),
              const _OfflineDownloadTile(),
              const SizedBox(height: 20),

              // ── Safety Disclaimer ─────────────────────────────────────────
              const _SectionHeader(label: 'Safety Disclaimer'),
              const _DisclaimerSection(),
              const SizedBox(height: 20),

              // ── Legal ──────────────────────────────────────────────────────
              const _SectionHeader(label: 'Legal'),
              const _LegalSection(),
              const SizedBox(height: 20),

              // ── Privacy ─────────────────────────────────────────────────
              const _SectionHeader(label: 'Privacy'),
              _PrivacySection(uid: user?.uid ?? ''),
              const SizedBox(height: 20),

              // ── Sign Out ──────────────────────────────────────────────────
              const _SignOutButton(),
              const SizedBox(height: 12),

              // ── Delete Account ────────────────────────────────────────────
              const _DeleteAccountButton(),
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

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

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

// ---------------------------------------------------------------------------
// Offline download tile
// ---------------------------------------------------------------------------
class _OfflineDownloadTile extends ConsumerStatefulWidget {
  const _OfflineDownloadTile();

  @override
  ConsumerState<_OfflineDownloadTile> createState() =>
      _OfflineDownloadTileState();
}

class _OfflineDownloadTileState extends ConsumerState<_OfflineDownloadTile> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final cacheService = ref.read(contentCacheServiceProvider);
      final count = await cacheService.prefetchAllContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Content downloaded successfully ($count exercises)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: _downloading ? null : _download,
        leading: Icon(Icons.cloud_download_outlined,
            color: cs.onSurface.withValues(alpha: _downloading ? 0.3 : 0.6)),
        title: Text(
          'Download for Offline',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: _downloading ? 0.4 : 1.0),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Save all exercises, briefs, and quizzes for offline use',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: _downloading ? 0.3 : 0.6),
            fontSize: 12,
          ),
        ),
        trailing: _downloading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile section
// ---------------------------------------------------------------------------
class _ProfileSection extends StatelessWidget {
  final AppUser? user;

  const _ProfileSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = user?.displayName ?? 'Student Pilot';
    final email = user?.email ?? '';
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primary,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/settings/profile'),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aircraft & Training section
// ---------------------------------------------------------------------------
class _AircraftSection extends StatelessWidget {
  final AppUser? user;

  const _AircraftSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final aircraft = _aircraftLabel(user?.aircraftType ?? '');
    final school = user?.flightSchool.isNotEmpty == true
        ? user!.flightSchool
        : 'Not set';
    final airfield = user?.airfieldIcao.isNotEmpty == true
        ? user!.airfieldIcao.toUpperCase()
        : 'Not set';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Aircraft type', value: aircraft),
          Divider(color: cs.outline, height: 20),
          _InfoRow(label: 'Flight school', value: school),
          Divider(color: cs.outline, height: 20),
          _InfoRow(label: 'Home airfield', value: airfield),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/settings/profile'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.outline),
                foregroundColor: cs.onSurface.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Edit Aircraft & Training'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription section
// ---------------------------------------------------------------------------
class _SubscriptionSection extends StatelessWidget {
  final AppUser? user;

  const _SubscriptionSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPremium = user?.isPremium ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium) ...[
            Row(
              children: [
                Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pro',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'You have Pro access to all exercises and features.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            if (user?.purchaseDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Purchased ${_formatDate(user!.purchaseDate!)}',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            Text(
              'Free Plan',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Free access covers your current exercise \u00B12 either side. Upgrade to Pro to unlock all 19 exercises, AI debriefs, and instructor sharing.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showPremiumPaywall(
                    context,
                    source: 'settings',
                    freeWindowStart: user?.freeWindowStart ?? 1,
                    freeWindowEnd: user?.freeWindowEnd ?? 3,
                  );
                },
                child: Text(
                  'Upgrade to Pro \u2014 \u00A3${AppConstants.premiumPriceGbp.toStringAsFixed(2)}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () async {
                  final success = await showPremiumPaywall(
                    context,
                    source: 'settings_restore',
                    freeWindowStart: user?.freeWindowStart ?? 1,
                    freeWindowEnd: user?.freeWindowEnd ?? 3,
                  );
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase restored successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: Text(
                  'Restore purchase',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ---------------------------------------------------------------------------
// Safety Disclaimer section
// ---------------------------------------------------------------------------
class _DisclaimerSection extends StatelessWidget {
  static const String _shortText =
      'Flight Path is a study aid only. It does not replace official flight '
      'training, your instructor\'s guidance, or official CAA publications. '
      'Never use this app in flight.';

  static const String _fullText =
      'Flight Path is a study aid only. It does not replace official flight '
      'training, your instructor\'s guidance, or official CAA publications. '
      'Never use this app in flight. Always conduct a full pre-flight briefing '
      'with your instructor.\n\n'
      'The information contained within this app is for educational and '
      'reference purposes only. Flight operations involve risk. Always follow '
      'your instructor\'s advice, current NOTAMs, and official CAA guidance. '
      'The app\'s AI-generated content is not a substitute for professional '
      'flight instruction.';

  const _DisclaimerSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'Safety Notice',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _shortText,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'View Full Disclaimer',
            button: true,
            child: GestureDetector(
              onTap: () => _showFullDisclaimer(context),
              child: Text(
                'View Full Disclaimer',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullDisclaimer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Safety Disclaimer',
          style: TextStyle(color: cs.onSurface),
        ),
        content: SingleChildScrollView(
          child: Text(
            _fullText,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal section
// ---------------------------------------------------------------------------
class _LegalSection extends StatelessWidget {
  const _LegalSection();

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not open link. Please try again later.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.privacy_tip_outlined,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'Privacy Policy',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            trailing: Icon(
              Icons.open_in_new,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            onTap: () =>
                _openUrl(context, 'https://getflightpath.app/privacy'),
          ),
          Divider(color: cs.outline, height: 1, indent: 56),
          ListTile(
            leading: Icon(
              Icons.description_outlined,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              'Terms of Service',
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
            trailing: Icon(
              Icons.open_in_new,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            onTap: () =>
                _openUrl(context, 'https://getflightpath.app/terms'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy section (GDPR data export)
// ---------------------------------------------------------------------------
class _PrivacySection extends StatefulWidget {
  final String uid;

  const _PrivacySection({required this.uid});

  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  bool _exporting = false;

  Future<void> _exportData() async {
    if (_exporting || widget.uid.isEmpty) return;
    setState(() => _exporting = true);

    try {
      FirebaseAnalytics.instance.logEvent(name: 'data_export_started');
      final uri = Uri(
        scheme: 'mailto',
        path: 'privacy@getflightpath.app',
        queryParameters: {
          'subject': 'Data Request — Flight Path',
          'body':
              'Hi,\n\nI would like to request a copy of my data.\n\n'
              'Account UID: ${widget.uid}\n\n'
              'Thank you.',
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch email client');
      }
      FirebaseAnalytics.instance.logEvent(name: 'data_export_completed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open email. Please email privacy@getflightpath.app directly.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: _exporting ? null : _exportData,
        leading: _exporting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.download_rounded,
                color: cs.onSurface.withValues(alpha: 0.6)),
        title: Text(
          _exporting ? 'Exporting\u2026' : 'Export My Data',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Download a copy of all your Flight Path data',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: _exporting
            ? null
            : Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications section
// ---------------------------------------------------------------------------
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => context.push('/settings/notifications'),
        leading: Icon(Icons.notifications_rounded,
            color: cs.onSurface.withValues(alpha: 0.6)),
        title: Text(
          'Notification Preferences',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Lesson reminders, spaced repetition, and more.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance section (theme toggle)
// ---------------------------------------------------------------------------
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

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
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: themeMode == ThemeMode.light,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 10),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: themeMode == ThemeMode.dark,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark),
              ),
              const SizedBox(width: 10),
              _ThemeOption(
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

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
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
class _AccessibilitySection extends ConsumerWidget {
  const _AccessibilitySection();

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

// ---------------------------------------------------------------------------
// Sign Out button
// ---------------------------------------------------------------------------
class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _confirmSignOut(context),
        leading: Icon(Icons.logout_rounded, color: cs.error),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: cs.error,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              FirebaseAnalytics.instance.logEvent(name: 'sign_out');
              await AuthService().signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete Account button
// ---------------------------------------------------------------------------
class _DeleteAccountButton extends ConsumerStatefulWidget {
  const _DeleteAccountButton();

  @override
  ConsumerState<_DeleteAccountButton> createState() =>
      _DeleteAccountButtonState();
}

class _DeleteAccountButtonState
    extends ConsumerState<_DeleteAccountButton> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'This will permanently delete your account and all your lesson data. '
          'This cannot be undone.',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete Account',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final uid = user.uid;

      await FirebaseAnalytics.instance.logEvent(name: 'account_deleted');

      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteAllUserData(uid);

      await AuthService().signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to delete account. Please try again or contact support.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        onTap: _deleting ? null : _confirmAndDelete,
        leading: _deleting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.error,
                ),
              )
            : Icon(Icons.delete_forever_rounded, color: cs.error),
        title: Text(
          _deleting ? 'Deleting account\u2026' : 'Delete Account',
          style: TextStyle(
            color: _deleting ? cs.error.withValues(alpha: 0.5) : cs.error,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Permanently removes your account and all data.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
