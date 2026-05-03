// Mock Skills Test — self-assessment against CAA examiner standards.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:go_router/go_router.dart';

import 'package:flight_path/core/constants/skills_test_standards.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ── Assessment state ─────────────────────────────────────────────────────────

enum _Result { pass, needsWork }

// ── Label derivation ─────────────────────────────────────────────────────────

/// Converts a skills-test key to a human-readable exercise label.
///
/// Examples:
///   'ex_06'       → 'Ex 6 — Straight and Level'
///   'ex_10_10a'   → 'Ex 10 10a — Slow Flight'
///   'ex_18_18a'   → 'Ex 18 18a — Navigation'
String _labelFromKey(String key) {
  // Strip 'ex_' prefix then replace underscores with spaces.
  final stripped = key.replaceFirst('ex_', '').replaceAll('_', ' ');
  // Title-case each word.
  final titled = stripped.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
  return 'Ex $titled';
}

// ── Screen ───────────────────────────────────────────────────────────────────

class MockSkillsTestScreen extends ConsumerStatefulWidget {
  const MockSkillsTestScreen({super.key});

  @override
  ConsumerState<MockSkillsTestScreen> createState() =>
      _MockSkillsTestScreenState();
}

class _MockSkillsTestScreenState extends ConsumerState<MockSkillsTestScreen> {
  final Map<String, _Result?> _results = {
    for (final key in skillsTestStandards.keys) key: null,
  };

  // Expansion state per card.
  final Map<String, bool> _expanded = {
    for (final key in skillsTestStandards.keys) key: false,
  };

  void _setResult(String key, _Result result) {
    setState(() {
      // Tapping the already-selected button deselects it.
      _results[key] = _results[key] == result ? null : result;
    });
  }

  void _reset() {
    setState(() {
      for (final key in _results.keys) {
        _results[key] = null;
      }
    });
  }

  Future<void> _saveSummary() async {
    final buffer = StringBuffer();
    buffer.writeln('Flight Path Training — Mock Skills Test Self-Assessment');
    buffer.writeln('');

    for (final entry in skillsTestStandards.entries) {
      final label = _labelFromKey(entry.key);
      final result = _results[entry.key];
      final resultStr = result == _Result.pass
          ? 'Pass'
          : result == _Result.needsWork
              ? 'Needs Work'
              : 'Not assessed';
      buffer.writeln('$label: $resultStr');
    }

    final assessed =
        _results.values.where((r) => r != null).length;
    final passes =
        _results.values.where((r) => r == _Result.pass).length;
    final needsWork =
        _results.values.where((r) => r == _Result.needsWork).length;

    buffer.writeln('');
    buffer.writeln(
        'Score: $assessed / ${skillsTestStandards.length} assessed · $passes Pass · $needsWork Needs Work');

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: 'Mock Skills Test Summary'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        ref.watch(premiumStatusProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const _AppBarTitle(),
        centerTitle: false,
      ),
      body: isPremium ? _assessmentBody(context) : _paywallBody(context),
    );
  }

  // ── Paywall ─────────────────────────────────────────────────────────────────

  Widget _paywallBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Pro lock card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pro feature',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The Mock Skills Test self-assessment is part of Pro. '
                    'Unlock CAA examiner standards for all 16 exercises plus '
                    'a shareable summary you can show your instructor.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => showPremiumPaywall(
                        context,
                        source: 'mock_skills_test',
                      ),
                      child: const Text('Unlock Pro'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Free fallback: AI Instructor ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'In the meantime',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use the AI Instructor to simulate a skills test — ask it '
                    'to quiz you on Principles of Flight, Air Law, or '
                    'Navigation, or to walk through an exercise debrief.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/ask-ai'),
                      child: const Text('Open AI Instructor'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Assessment body ─────────────────────────────────────────────────────────

  Widget _assessmentBody(BuildContext context) {
    final assessed =
        _results.values.where((r) => r != null).length;
    final passes =
        _results.values.where((r) => r == _Result.pass).length;
    final needsWork =
        _results.values.where((r) => r == _Result.needsWork).length;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: skillsTestStandards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final key =
                  skillsTestStandards.keys.elementAt(index);
              final standards = skillsTestStandards[key]!;
              final label = _labelFromKey(key);
              return _ExerciseCard(
                label: label,
                standards: standards,
                result: _results[key],
                expanded: _expanded[key]!,
                onToggleExpand: () => setState(
                    () => _expanded[key] = !_expanded[key]!),
                onSetResult: (r) => _setResult(key, r),
              );
            },
          ),
        ),
        _FooterBar(
          assessed: assessed,
          total: skillsTestStandards.length,
          passes: passes,
          needsWork: needsWork,
          onReset: _reset,
          onSave: _saveSummary,
        ),
      ],
    );
  }
}

// ── AppBar title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Mock Skills Test',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Text(
          'Self-assessment',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final String label;
  final String standards;
  final _Result? result;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<_Result> onSetResult;

  const _ExerciseCard({
    required this.label,
    required this.standards,
    required this.result,
    required this.expanded,
    required this.onToggleExpand,
    required this.onSetResult,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row.
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Standards text — truncated or full.
          GestureDetector(
            onTap: onToggleExpand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standards,
                  maxLines: expanded ? null : 3,
                  overflow:
                      expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expanded ? 'Show less' : 'Show more',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Toggle buttons.
          Row(
            children: [
              _ResultButton(
                label: 'Pass',
                selected: result == _Result.pass,
                activeColor: AppColors.success,
                onTap: () => onSetResult(_Result.pass),
              ),
              const SizedBox(width: 8),
              _ResultButton(
                label: 'Needs Work',
                selected: result == _Result.needsWork,
                activeColor: AppColors.warning,
                onTap: () => onSetResult(_Result.needsWork),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Result toggle button ──────────────────────────────────────────────────────

class _ResultButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ResultButton({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : cs.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? activeColor
                : cs.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? activeColor
                : cs.onSurface.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Sticky footer ─────────────────────────────────────────────────────────────

class _FooterBar extends StatelessWidget {
  final int assessed;
  final int total;
  final int passes;
  final int needsWork;
  final VoidCallback onReset;
  final VoidCallback onSave;

  const _FooterBar({
    required this.assessed,
    required this.total,
    required this.passes,
    required this.needsWork,
    required this.onReset,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$assessed / $total assessed',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$passes Pass · $needsWork Needs Work',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface.withValues(alpha: 0.5),
              textStyle: const TextStyle(fontSize: 13),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reset'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Save Summary'),
          ),
        ],
      ),
    );
  }
}
