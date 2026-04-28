// QXC Guide — educational guide for planning a qualifying cross-country flight.
// Chapter 1 is free. Chapters 2–6 require a premium subscription.
// Progress (which chapters have been read) is stored in SharedPreferences.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ---------------------------------------------------------------------------
// SharedPreferences keys
// ---------------------------------------------------------------------------

const String _kQxcProgressPrefix = 'qxc_chapter_read_';

String _progressKey(int chapterIndex) => '$_kQxcProgressPrefix$chapterIndex';

// ---------------------------------------------------------------------------
// Chapter metadata
// ---------------------------------------------------------------------------

class _ChapterMeta {
  final int index; // 0-based
  final String number; // Display: "1", "2" …
  final String title;
  final bool isPremium;

  const _ChapterMeta({
    required this.index,
    required this.number,
    required this.title,
    required this.isPremium,
  });
}

const List<_ChapterMeta> _chapters = [
  _ChapterMeta(index: 0, number: '1', title: 'What is a QXC?', isPremium: false),
  _ChapterMeta(index: 1, number: '2', title: 'The PLOG — Pilot\'s Log', isPremium: true),
  _ChapterMeta(index: 2, number: '3', title: 'The Wind Triangle', isPremium: true),
  _ChapterMeta(index: 3, number: '4', title: 'Fuel Planning', isPremium: true),
  _ChapterMeta(index: 4, number: '5', title: 'Airspace and NOTAMs', isPremium: true),
  _ChapterMeta(index: 5, number: '6', title: 'On the Day', isPremium: true),
];

// ---------------------------------------------------------------------------
// Root screen — chapter list
// ---------------------------------------------------------------------------

/// Entry point. Displays all chapter cards with locked/unlocked state.
class QxcGuideScreen extends ConsumerStatefulWidget {
  const QxcGuideScreen({super.key});

  @override
  ConsumerState<QxcGuideScreen> createState() => _QxcGuideScreenState();
}

class _QxcGuideScreenState extends ConsumerState<QxcGuideScreen> {
  final List<bool> _read = List.filled(_chapters.length, false);

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _chapters.length; i++) {
        _read[i] = prefs.getBool(_progressKey(i)) ?? false;
      }
    });
  }

  Future<void> _markRead(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_progressKey(index), true);
    if (!mounted) return;
    setState(() => _read[index] = true);
  }

  Future<void> _onChapterTap(BuildContext context, _ChapterMeta meta, bool isPremium) async {
    if (meta.isPremium && !isPremium) {
      final purchased = await showPremiumPaywall(context, source: 'qxc_guide_chapter_${meta.number}');
      if (!purchased || !mounted) return;
    }
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ChapterScreen(meta: meta),
      ),
    );
    if (result == true) {
      await _markRead(meta.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider).valueOrNull ?? false;
    final cs = Theme.of(context).colorScheme;

    final readCount = _read.where((r) => r).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QXC Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qualifying Cross-Country',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything you need to plan and fly your solo QXC — from understanding the CAA requirement to debriefing yourself afterwards.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$readCount of ${_chapters.length} chapters read',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _chapters.isEmpty ? 0 : readCount / _chapters.length,
                        backgroundColor: cs.outline.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chapter list
          ...List.generate(_chapters.length, (i) {
            final meta = _chapters[i];
            final isRead = _read[i];
            final isLocked = meta.isPremium && !isPremium;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChapterCard(
                meta: meta,
                isRead: isRead,
                isLocked: isLocked,
                onTap: () => _onChapterTap(context, meta, isPremium),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter list card
// ---------------------------------------------------------------------------

class _ChapterCard extends StatelessWidget {
  final _ChapterMeta meta;
  final bool isRead;
  final bool isLocked;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.meta,
    required this.isRead,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? AppColors.primary.withValues(alpha: 0.4)
                : cs.outline,
            width: isRead ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Chapter number badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLocked
                    ? cs.outline.withValues(alpha: 0.15)
                    : isRead
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isLocked
                    ? Icon(Icons.lock_outline_rounded,
                        color: AppColors.onSurfaceVariant, size: 18)
                    : isRead
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary, size: 20)
                        : Text(
                            meta.number,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 14),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapter ${meta.number}',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.title,
                    style: TextStyle(
                      color: isLocked ? AppColors.onSurfaceVariant : cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLocked
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              color: isLocked
                  ? AppColors.onSurfaceVariant.withValues(alpha: 0.5)
                  : AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter detail screen
// ---------------------------------------------------------------------------

/// Wraps a scrollable chapter body. On pop, returns `true` so the list screen
/// can mark the chapter as read.
class _ChapterScreen extends StatelessWidget {
  final _ChapterMeta meta;

  const _ChapterScreen({required this.meta});

  Widget _body() {
    switch (meta.index) {
      case 0:
        return const _Chapter1Body();
      case 1:
        return const _Chapter2Body();
      case 2:
        return const _Chapter3Body();
      case 3:
        return const _Chapter4Body();
      case 4:
        return const _Chapter5Body();
      case 5:
        return const _Chapter6Body();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Chapter ${meta.number}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: PopScope(
        // canPop: false so we control the pop and always return true (read).
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(true);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _body(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layout widgets
// ---------------------------------------------------------------------------

/// A titled card containing any child widget.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;

  const _Section({
    required this.title,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
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
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Body text: 14sp, height 1.6, theme-aware colour.
class _Body extends StatelessWidget {
  final String text;

  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.onSurface,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}

/// Bullet list rendered from newline-separated text.
class _Bullets extends StatelessWidget {
  final String text;

  const _Bullets(this.text);

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Key-value table row, used for PLOG columns, etc.
class _TableRow extends StatelessWidget {
  final String label;
  final String value;

  const _TableRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlighted callout box (orange border, tinted background).
class _Callout extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Callout({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Monospace-style block for worked examples, tables, or ASCII diagrams.
class _CodeBlock extends StatelessWidget {
  final String text;

  const _CodeBlock(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.7,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini-quiz widget
// ---------------------------------------------------------------------------

/// Single question with multiple choices. Answer revealed inline on tap.
class _QuizQuestion extends StatefulWidget {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  @override
  State<_QuizQuestion> createState() => _QuizQuestionState();
}

class _QuizQuestionState extends State<_QuizQuestion> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answered = _selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.question,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(widget.options.length, (i) {
          final isSelected = _selected == i;
          final isCorrect = i == widget.correctIndex;
          Color borderColor;
          Color bgColor;
          Color textColor = cs.onSurface;

          if (!answered) {
            borderColor = cs.outline;
            bgColor = cs.surfaceContainerHighest;
          } else if (isCorrect) {
            borderColor = AppColors.success;
            bgColor = AppColors.success.withValues(alpha: 0.1);
            textColor = AppColors.success;
          } else if (isSelected) {
            borderColor = AppColors.error;
            bgColor = AppColors.error.withValues(alpha: 0.08);
            textColor = AppColors.error;
          } else {
            borderColor = cs.outline.withValues(alpha: 0.4);
            bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
            textColor = AppColors.onSurfaceVariant;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: answered ? null : () => setState(() => _selected = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: answered && isCorrect ? 1.5 : 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1.5),
                        color: answered && isCorrect
                            ? AppColors.success.withValues(alpha: 0.15)
                            : answered && isSelected
                                ? AppColors.error.withValues(alpha: 0.1)
                                : Colors.transparent,
                      ),
                      child: answered && isCorrect
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 14)
                          : answered && isSelected
                              ? const Icon(Icons.close_rounded,
                                  color: AppColors.error, size: 14)
                              : null,
                    ),
                    Expanded(
                      child: Text(
                        widget.options[i],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (answered) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              widget.explanation,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A section card containing a mini-quiz (2–3 questions).
class _QuizCard extends StatelessWidget {
  final List<_QuizQuestion> questions;

  const _QuizCard({required this.questions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.quiz_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Check Your Understanding',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(questions.length, (i) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) ...[
                  Divider(color: cs.outline, height: 24),
                ],
                questions[i],
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter 1: What is a QXC?  (FREE)
// ---------------------------------------------------------------------------

class _Chapter1Body extends StatelessWidget {
  const _Chapter1Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. The CAA requirement
        _Section(
          title: 'The CAA Requirement',
          icon: Icons.gavel_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'To be issued a UK PPL, you must complete a qualifying cross-country (QXC) as solo pilot-in-command. The CAA specifies the following minimum criteria:',
              ),
              const SizedBox(height: 16),
              const _Callout(
                icon: Icons.info_outline_rounded,
                text: 'Total route distance: 150 nautical miles (nm) minimum.\n\nLegs: at least 3 legs, meaning you must visit at least two intermediate airfields.\n\nLandings: full-stop landings at two airfields different from your departure aerodrome.',
              ),
              const SizedBox(height: 14),
              const _Body(
                'A full-stop landing means you must come to a complete stop on the runway — a touch-and-go does not count. You must taxi clear of the runway and come to rest before departing again.\n\nThe 150 nm is measured as the sum of the great-circle distances between consecutive waypoints, not as a straight-line distance from departure to destination.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Why it matters
        _Section(
          title: 'Why It Matters',
          icon: Icons.school_rounded,
          child: const _Body(
            'The QXC is not merely a box-ticking exercise. It is the point at which you demonstrate that you can operate as a self-sufficient pilot without an instructor on board.\n\nYou will be making real navigation decisions, communicating with multiple ATC units or making self-announced calls at ATZs, managing fuel, identifying airspace, and responding to changing conditions — all without anyone to bail you out.\n\nFor most students it is the most demanding flight of their training. It is also the most formative. Students who plan thoroughly and fly the plan consistently tend to find the skills test navigation exercise straightforward. Students who wing it on the QXC tend to struggle later.',
          ),
        ),
        const SizedBox(height: 20),

        // 3. What the examiner expects
        _Section(
          title: 'What the Examiner Expects on the Skills Test',
          icon: Icons.assignment_turned_in_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'The navigation exercise on the skills test is assessed against the CAA\'s Flight Examiner/Skill Test Report criteria. Key points:',
              ),
              const SizedBox(height: 14),
              const _Bullets(
                'You must arrive at each turning point within 3 nm and within 3 minutes of your planned ETA.\n'
                'Heading must be held to within +/- 5 degrees.\n'
                'Altitude must be held to within +/- 150 ft of your planned cruising altitude.\n'
                'You must identify your position at all times if asked by the examiner.\n'
                'You must demonstrate fuel awareness — know your remaining endurance.\n'
                'A diversion exercise may be set: you will be asked to divert to an alternative airfield mid-route and must replan in the air.',
              ),
              const SizedBox(height: 14),
              const _Body(
                'The examiner is not looking for perfection — they are looking for a safe, organised, methodical approach. A student who acknowledges uncertainty and applies the lost procedure correctly will pass; a student who bluffs and flies in the wrong direction will not.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quiz
        _QuizCard(
          questions: [
            _QuizQuestion(
              question: 'What is the minimum total route distance for a UK PPL qualifying cross-country?',
              options: [
                '100 nautical miles',
                '150 nautical miles',
                '200 nautical miles',
                '250 nautical miles',
              ],
              correctIndex: 1,
              explanation: 'CAA regulations require a minimum of 150 nm for the QXC, with at least 3 legs and full-stop landings at 2 different airfields from the departure aerodrome.',
            ),
            _QuizQuestion(
              question: 'Which of the following counts as a qualifying landing on the QXC?',
              options: [
                'A touch-and-go at a grass strip',
                'A low pass over the runway',
                'A full-stop landing with taxi clear of the runway',
                'A go-around to a landing within the same ATZ',
              ],
              correctIndex: 2,
              explanation: 'Only a full-stop landing counts — you must come to a complete stop and taxi clear of the runway. Touch-and-goes and stop-and-goes where you do not exit the runway do not qualify.',
            ),
            _QuizQuestion(
              question: 'On the skills test navigation exercise, to what tolerance must you arrive at a turning point?',
              options: [
                '5 nm and 5 minutes',
                '2 nm and 2 minutes',
                '3 nm and 3 minutes',
                '1 nm and 1 minute',
              ],
              correctIndex: 2,
              explanation: 'The CAA standard requires arrival within 3 nm of the turning point and within 3 minutes of the planned ETA.',
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter 2: The PLOG  (PREMIUM)
// ---------------------------------------------------------------------------

class _Chapter2Body extends StatelessWidget {
  const _Chapter2Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. What is a PLOG
        _Section(
          title: 'What Is a PLOG?',
          icon: Icons.table_chart_rounded,
          child: const _Body(
            'A PLOG (Pilot\'s Log, or navigation log) is the structured form you complete during pre-flight planning and carry in the cockpit. It records every waypoint on your route with the navigation data you calculated on the ground, plus space to record actual times as you fly.\n\nThe PLOG serves two purposes. Before flight, it forces you to work through the full navigation calculation methodically. In the air, it becomes your reference: you know the heading to steer, the ETA at the next waypoint, and how much fuel you should have used.',
          ),
        ),
        const SizedBox(height: 20),

        // 2. Columns
        _Section(
          title: 'PLOG Columns Explained',
          icon: Icons.view_column_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body('Each row in the PLOG represents one leg. The standard columns are:'),
              const SizedBox(height: 14),
              const _TableRow(label: 'Waypoint', value: 'The name or ICAO identifier of the fix — airfield, prominent landmark, or VOR/NDB.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Track (°T)', value: 'The direction from the previous waypoint to this one, measured in degrees True. Measured off the chart using a protractor.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Var', value: 'Magnetic variation for the region. In the UK, currently approximately 0–2°W. Applied to convert track °T to track °M.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Track (°M)', value: 'Track in degrees Magnetic = Track °T + variation west. This is the bearing along the route corrected for variation.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'WCA', value: 'Wind Correction Angle. The angle you must offset your heading from the track to counteract the crosswind component. Calculated with the 1-in-60 rule or a navigation computer.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Heading (°M)', value: 'The heading you actually fly: Track °M +/- WCA. Corrected to nearest degree.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'TAS', value: 'True Air Speed. Your indicated airspeed corrected for altitude and temperature. At typical PPL training altitudes (2,000–4,500 ft), TAS ≈ IAS + 2% per 1,000 ft.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'GS', value: 'Groundspeed. Your speed over the ground, accounting for the wind. The headwind/tailwind component of the wind is added to or subtracted from TAS.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Distance (nm)', value: 'The direct distance between the two waypoints, measured off the chart.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Est. Time', value: 'Estimated elapsed time for the leg: Distance ÷ Groundspeed × 60, in minutes.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'ETA', value: 'Estimated Time of Arrival at this waypoint, calculated from wheels-up time plus cumulative leg times.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'ATA', value: 'Actual Time of Arrival. Filled in once airborne; compare against ETA and update your subsequent ETAs if there is a discrepancy.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Fuel Required', value: 'Fuel burn for this leg: fuel flow (in litres or US gallons per hour) × leg time in hours.'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Worked example
        _Section(
          title: 'Worked Example: EGBT → EGBJ → EGTC → EGBT',
          icon: Icons.route_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'A three-leg route departing Turweston (EGBT), routing via Gloucestershire (EGBJ), then Cranfield (EGTC), and returning to Turweston. Wind: 270/15 kt. TAS: 100 kt. Fuel burn: 6 USG/hr.',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                'LEG 1: EGBT → EGBJ\n'
                '  Track °T    : 264°\n'
                '  Variation   : 1°W\n'
                '  Track °M    : 265° (264 + 1)\n'
                '  Wind        : 270/15\n'
                '  WCA         : +3° (wind from left, drift right)\n'
                '  Heading °M  : 268°\n'
                '  GS          : ~99 kt (slight headwind component)\n'
                '  Distance    : 44 nm\n'
                '  Est time    : 27 min\n'
                '  Fuel        : 2.7 USG\n',
              ),
              const SizedBox(height: 10),
              const _CodeBlock(
                'LEG 2: EGBJ → EGTC\n'
                '  Track °T    : 082°\n'
                '  Variation   : 1°W\n'
                '  Track °M    : 083°\n'
                '  Wind        : 270/15\n'
                '  WCA         : -9° (wind from right, drift left)\n'
                '  Heading °M  : 074°\n'
                '  GS          : ~100 kt (pure crosswind, negligible GS effect)\n'
                '  Distance    : 48 nm\n'
                '  Est time    : 29 min\n'
                '  Fuel        : 2.9 USG\n',
              ),
              const SizedBox(height: 10),
              const _CodeBlock(
                'LEG 3: EGTC → EGBT\n'
                '  Track °T    : 221°\n'
                '  Variation   : 1°W\n'
                '  Track °M    : 222°\n'
                '  Wind        : 270/15\n'
                '  WCA         : -6°\n'
                '  Heading °M  : 216°\n'
                '  GS          : ~108 kt (tailwind component)\n'
                '  Distance    : 28 nm\n'
                '  Est time    : 16 min\n'
                '  Fuel        : 1.6 USG\n',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.info_outline_rounded,
                text: 'Total: 120 nm, ~72 min, ~7.2 USG. Note this route is only 120 nm — you would need to extend it or add legs to meet the 150 nm QXC minimum.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Interactive problem
        _Section(
          title: 'Interactive: Calculate the Heading',
          icon: Icons.calculate_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Given:\n  Track: 270°M\n  Wind: 220/15 kt\n  TAS: 100 kt\n\nWhat heading should you fly?',
              ),
              const SizedBox(height: 14),
              const _Body('Working:'),
              const SizedBox(height: 8),
              const _CodeBlock(
                'Step 1 — Find the wind component:\n'
                '  Wind direction is 220°, track is 270°.\n'
                '  Angle between wind and track = 270 - 220 = 50°.\n'
                '\n'
                'Step 2 — Find the crosswind component:\n'
                '  XW = windspeed × sin(angle) = 15 × sin(50°) ≈ 15 × 0.77 ≈ 11.5 kt\n'
                '  Wind is from the left (south-west), so drift is to the right.\n'
                '\n'
                'Step 3 — Calculate WCA (1-in-60 approximation):\n'
                '  WCA ≈ (XW / TAS) × 60 = (11.5 / 100) × 60 ≈ 7°\n'
                '  Wind from the left → WCA is positive (turn into wind = left)\n'
                '\n'
                'Step 4 — Apply WCA to track:\n'
                '  Heading = Track - WCA = 270 - 7 = 263°M\n',
              ),
              const SizedBox(height: 10),
              const _Callout(
                icon: Icons.check_circle_outline_rounded,
                text: 'Answer: fly 263°M. The wind is pushing you right of track, so you turn left (into the wind) to maintain the planned track of 270°M.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quiz
        _QuizCard(
          questions: [
            _QuizQuestion(
              question: 'Track is 090°M. Variation is 2°W. What is the track in degrees True?',
              options: [
                '088°T',
                '092°T',
                '090°T',
                '086°T',
              ],
              correctIndex: 0,
              explanation: 'Track °T = Track °M - variation west = 090 - 2 = 088°T. Remember: "Variation West, Magnetic Best" — magnetic value is larger than true when variation is westerly.',
            ),
            _QuizQuestion(
              question: 'Your groundspeed is 95 kt and the leg distance is 57 nm. What is the estimated leg time?',
              options: [
                '30 min',
                '36 min',
                '40 min',
                '27 min',
              ],
              correctIndex: 1,
              explanation: 'Time = (Distance / GS) × 60 = (57 / 95) × 60 = 0.6 × 60 = 36 minutes.',
            ),
            _QuizQuestion(
              question: 'Wind is directly on the nose (headwind). How does this affect groundspeed?',
              options: [
                'Groundspeed increases by the full wind speed',
                'Groundspeed is unaffected',
                'Groundspeed decreases by the full wind speed',
                'Groundspeed decreases by half the wind speed',
              ],
              correctIndex: 2,
              explanation: 'A direct headwind reduces groundspeed by the full wind speed component. GS = TAS - headwind. A 20 kt headwind with TAS 100 kt gives GS = 80 kt.',
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter 3: The Wind Triangle  (PREMIUM)
// ---------------------------------------------------------------------------

class _Chapter3Body extends StatelessWidget {
  const _Chapter3Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Vector Addition',
          icon: Icons.timeline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Navigation in a moving air mass is a vector problem. Three vectors are involved:\n\n1. Heading vector — the direction the aircraft\'s nose points, at TAS.\n2. Wind vector — the direction and speed the air mass is moving over the ground.\n3. Track vector — the resulting path of the aircraft over the ground, at groundspeed.\n\nThe relationship is:\n    Track + Wind = Heading  (vector sum)\n\nOr equivalently:\n    Heading = Track - Wind  (solve for heading given desired track)',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                '           N\n'
                '           |\n'
                '    Wind   |\n'
                '  <--------+\n'
                '           |  \\\n'
                '           |   \\  Heading vector (TAS)\n'
                '           |    \\\n'
                '           +------> Track (GS)\n\n'
                'The wind vector pushes the aircraft off the intended track.\n'
                'Correcting by WCA into the wind puts the track back on course.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'The 1-in-60 Rule',
          icon: Icons.square_foot_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'At 60 nm from a point, 1 nm of displacement corresponds to 1 degree of bearing. This is the 1-in-60 rule, and it underpins most mental arithmetic in VFR navigation.',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                'At distance D, lateral displacement X gives:\n'
                '  Bearing error (degrees) = (X / D) × 60\n\n'
                'Example: 3 nm off track at 45 nm:\n'
                '  Error = (3 / 45) × 60 = 4°\n',
              ),
              const SizedBox(height: 14),
              const _Body('Applied to wind correction:'),
              const SizedBox(height: 8),
              const _CodeBlock(
                'WCA (degrees) = (crosswind component / TAS) × 60\n\n'
                'Example: 12 kt crosswind, TAS 100 kt:\n'
                '  WCA = (12 / 100) × 60 = 7.2° ≈ 7°\n',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.lightbulb_outline_rounded,
                text: 'The 1-in-60 rule is an approximation valid when angles are small (below about 20°). For large angles you need a navigation computer or the full trigonometric solution, but for VFR planning the approximation is accurate enough.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Headwind and Tailwind Component',
          icon: Icons.air_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'The wind also affects groundspeed through its headwind or tailwind component. Only the component along the track axis matters for speed:',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                'HW/TW component = windspeed × cos(angle between wind and track)\n\n'
                'Example: wind 330/20, track 360°\n'
                '  Angle = 360 - 330 = 30°\n'
                '  HW/TW = 20 × cos(30°) = 20 × 0.866 = 17 kt tailwind\n'
                '  GS = TAS + 17 = 100 + 17 = 117 kt\n',
              ),
              const SizedBox(height: 14),
              const _Body(
                'For mental arithmetic: if the wind is within 30° of the track axis, treat it as roughly a full head/tailwind. If it is at 60°, halve it. If it is at 90°, there is no headwind/tailwind component at all — just crosswind.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Practice Problem',
          icon: Icons.calculate_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Given:\n  Track: 090°M\n  Wind: 360/20 kt\n  TAS: 95 kt\n\nCalculate the heading to fly and the groundspeed.',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                'CROSSWIND COMPONENT:\n'
                '  Angle between wind (360°) and track (090°) = 90°\n'
                '  XW = 20 × sin(90°) = 20 × 1 = 20 kt (from the north, drift south)\n\n'
                'WIND CORRECTION ANGLE:\n'
                '  WCA = (20 / 95) × 60 = 12.6° ≈ 13°\n'
                '  Wind from north (left of eastbound track) → turn into wind (north)\n'
                '  Heading = 090 - 13 = 077°M\n\n'
                'HEADWIND/TAILWIND COMPONENT:\n'
                '  Angle to track = 90°, so cos(90°) = 0\n'
                '  No head/tailwind component.\n'
                '  GS ≈ TAS = 95 kt\n\n'
                'ANSWER: Fly 077°M at 95 kt groundspeed.\n',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _QuizCard(
          questions: [
            _QuizQuestion(
              question: 'TAS is 90 kt. Crosswind component is 15 kt. Using the 1-in-60 rule, what is the WCA?',
              options: [
                '8°',
                '10°',
                '12°',
                '15°',
              ],
              correctIndex: 1,
              explanation: 'WCA = (XW / TAS) × 60 = (15 / 90) × 60 = 10°. The 1-in-60 rule gives a good approximation for wind correction angles encountered at PPL speeds.',
            ),
            _QuizQuestion(
              question: 'Wind is directly on the beam (90° to the track). What is the headwind/tailwind component?',
              options: [
                'Equal to the full wind speed',
                'Half the wind speed',
                'Zero',
                'Equal to the crosswind component',
              ],
              correctIndex: 2,
              explanation: 'cos(90°) = 0, so a 90° crosswind has zero headwind or tailwind component. It contributes only drift, not a groundspeed change.',
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter 4: Fuel Planning  (PREMIUM)
// ---------------------------------------------------------------------------

class _Chapter4Body extends StatelessWidget {
  const _Chapter4Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Endurance vs Range',
          icon: Icons.local_gas_station_rounded,
          child: const _Body(
            'Endurance is how long the aircraft can fly — expressed in hours and minutes — given the fuel on board and the fuel consumption rate. It is independent of groundspeed.\n\nRange is how far the aircraft can travel — expressed in nautical miles. Range depends on both endurance and groundspeed:\n    Range = Endurance × Groundspeed\n\nFor planning purposes you calculate endurance first, then check that your planned route falls comfortably within that endurance with reserves to spare.',
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Fuel Burn Figures',
          icon: Icons.speed_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Fuel consumption is published in the aircraft\'s Pilot Operating Handbook (POH). For a PA-28 Cherokee or Warrior at typical cruise power settings:',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                'Typical PA-28 cruise (75% power at 4,000 ft ISA):\n'
                '  Fuel burn: approximately 6.0–7.0 US gallons per hour\n'
                '  TAS:       approximately 105–115 kt\n\n'
                'Taxi and run-up allowance: 1.0 USG\n'
                'Climb allowance: add ~10% to cruise fuel for the climb phase\n',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.warning_amber_rounded,
                text: 'Always use the figures from your specific aircraft\'s POH, not generic estimates. Fuel consumption varies with aircraft age, engine condition, mixture management, and altitude.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'CAA Reserve Requirements',
          icon: Icons.shield_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'For VFR flight, UK regulations (derived from EU-OPS and NCO.OP.125) require that you carry sufficient fuel to complete the planned route plus a fixed reserve of 30 minutes at normal cruise consumption.',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.info_outline_rounded,
                text: 'Fixed VFR reserve: 30 minutes at normal cruise.\n\nThis is a legal minimum, not a comfort margin. Most instructors and operators recommend a personal minimum of 45 minutes to allow for unexpected diversions, extended holds, or headwinds greater than planned.',
              ),
              const SizedBox(height: 14),
              const _Body(
                'You must also consider fuel required to reach an alternate aerodrome if your destination is forecast to go below minima. Even for VFR flights, it is good practice to identify a suitable alternate and include alternate fuel in your calculation.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Alternate Planning',
          icon: Icons.alt_route_rounded,
          child: const _Body(
            'An alternate is required when:\n\n1. The destination weather is forecast to be at or below certain minima at the estimated time of arrival.\n2. You are operating in circumstances where the destination may become unavailable (e.g. flying at night, instrument conditions).\n\nFor VFR day operations, you may not be legally required to file an alternate, but you should always have one in mind and carry the fuel to reach it.\n\nAlternate fuel calculation:\n    Alternate fuel = fuel burn rate × estimated flight time to alternate\n\nChoose an alternate that is within reasonable range, has adequate facilities, and whose weather forecast differs from your destination (i.e. it is unlikely to close at the same time for the same reason).',
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Worked Fuel Calculation',
          icon: Icons.calculate_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Route: 3 legs, total 150 nm. Fuel burn: 6 USG/hr. Average GS: 95 kt. Alternate: 25 nm from destination.',
              ),
              const SizedBox(height: 14),
              const _CodeBlock(
                'TRIP FUEL:\n'
                '  Route time = 150 / 95 × 60 = 94.7 min ≈ 1.58 hr\n'
                '  Trip fuel = 1.58 × 6.0 = 9.5 USG\n\n'
                'TAXI + RUN-UP:\n'
                '  Allow 1.0 USG\n\n'
                'FIXED RESERVE (30 min):\n'
                '  Reserve = 0.5 × 6.0 = 3.0 USG\n\n'
                'ALTERNATE FUEL:\n'
                '  Alt time = 25 / 95 × 60 = 15.8 min ≈ 0.26 hr\n'
                '  Alt fuel = 0.26 × 6.0 = 1.6 USG\n\n'
                'TOTAL REQUIRED:\n'
                '  9.5 + 1.0 + 3.0 + 1.6 = 15.1 USG\n\n'
                'USABLE FUEL (PA-28-161, standard tanks): 48 USG\n'
                'MARGIN: 48 - 15.1 = 32.9 USG — well within limits.\n',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _QuizCard(
          questions: [
            _QuizQuestion(
              question: 'What is the minimum legal VFR fuel reserve required by UK regulations?',
              options: [
                '20 minutes at cruise',
                '30 minutes at cruise',
                '45 minutes at cruise',
                '1 hour at cruise',
              ],
              correctIndex: 1,
              explanation: 'NCO.OP.125 requires a fixed reserve of 30 minutes at normal cruise consumption for VFR flight. This is a legal minimum — many operators impose a higher personal minimum.',
            ),
            _QuizQuestion(
              question: 'Fuel burn is 7 USG/hr. Your planned flight time is 1 hr 15 min. How much trip fuel do you need?',
              options: [
                '7.0 USG',
                '8.75 USG',
                '8.0 USG',
                '9.5 USG',
              ],
              correctIndex: 1,
              explanation: 'Trip fuel = burn rate × time = 7 × 1.25 = 8.75 USG. Convert 1 hr 15 min to decimal hours: 75 min ÷ 60 = 1.25 hr.',
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter 5: Airspace and NOTAMs  (PREMIUM)
// ---------------------------------------------------------------------------

class _Chapter5Body extends StatelessWidget {
  const _Chapter5Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'UK Airspace Classes',
          icon: Icons.layers_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body('ICAO classifies airspace A through G. The classes relevant to VFR nav flights in the UK are:'),
              const SizedBox(height: 14),
              const _TableRow(label: 'Class A', value: 'IFR only. VFR flight is not permitted. London TMA, some airway structures. You must route around it.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Class C', value: 'Both IFR and VFR permitted, but VFR requires an ATC clearance and two-way radio. Scottish TMA above FL 100.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Class D', value: 'Both IFR and VFR permitted with ATC clearance and two-way radio. Most UK CTRs (e.g. Birmingham, Luton, Bristol). You must call ATC and request a transit or routing around it.'),
              Divider(color: Theme.of(context).colorScheme.outline, height: 12),
              const _TableRow(label: 'Class G', value: 'Uncontrolled airspace. No clearance required. Most low-level UK airspace outside CTRs and TMAs. Standard PPL nav training operates almost entirely in Class G.'),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.info_outline_rounded,
                text: 'The UK does not currently use Class B or Class E airspace at lower levels. Class F (advisory routes) exists but is uncommon in primary training areas.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'How to Check Airspace',
          icon: Icons.search_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bullets(
                'AIS.org.uk (UK AIP) — the authoritative source for all UK aeronautical information. ENR 1.4 covers airspace classification. The AIP is updated via the AIRAC cycle every 28 days.\n'
                'SkyDemon — flight planning software with airspace drawn on the moving map. Particularly useful for visualising controlled airspace boundaries and heights.\n'
                '1800wxbrief / NATS Pre-flight Information Bulletin — consolidated briefing including active NOTAMs and airspace status.\n'
                'Airspace & NOTAMs section of the NATS AIS portal — search by date, area, and ICAO identifier.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'NOTAM Awareness',
          icon: Icons.notifications_active_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'A NOTAM (Notice to Air Missions) is a notice filed with aviation authorities to alert pilots of changes that may affect the safety of a flight. Before any nav flight, you must check NOTAMs for the entire route — not just your departure and destination.',
              ),
              const SizedBox(height: 14),
              const _Body('Key NOTAM items to look for:'),
              const SizedBox(height: 8),
              const _Bullets(
                'Temporary airspace restrictions (TRA/TSA/D areas that may be active)\n'
                'Red Arrows or display team activity (these generate large temporary restricted areas)\n'
                'Laser activity and illuminated sites (potential interference with vision)\n'
                'Parachute dropping zones — listed with heights and times\n'
                'UAS (drone) flight operations — some are notified via NOTAM\n'
                'Runway closures or taxiway works at en-route airfields\n'
                'Radio navigation aid outages (VOR/NDB off air)\n'
                'Bird hazard warnings',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.warning_amber_rounded,
                text: 'Do not just skim NOTAM briefings. Read every NOTAM for your route area. A missed parachute drop zone or restricted area is an avoidable incident.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Danger Areas',
          icon: Icons.dangerous_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Danger areas (prefixed "D" in the UK, e.g. D129) are defined volumes of airspace where operations may be hazardous to non-participating aircraft. They include military ranges, weapons training areas, and high-intensity military operations.',
              ),
              const SizedBox(height: 14),
              const _Body('How to handle danger areas:'),
              const SizedBox(height: 8),
              const _Bullets(
                'Check activation times in the AIP (ENR 5.1 for UK danger areas) and by NOTAM.\n'
                'If the danger area is active during your planned routing time, you must route around it. Add the diversion to your PLOG and recalculate.\n'
                'Some danger areas have a crossing service: a designated frequency (often London Information or a specific area frequency) where you can obtain crossing approval from the controlling authority. Check the AIP entry.\n'
                'If in doubt, assume the danger area is active and route around it. The airspace exists to protect you from live weapons, not as a bureaucratic inconvenience.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _QuizCard(
          questions: [
            _QuizQuestion(
              question: 'You want to fly VFR through Class D airspace. What do you need?',
              options: [
                'Nothing — Class D is uncontrolled',
                'An ATC clearance and established two-way radio contact',
                'IFR flight plan only',
                'A special VFR clearance from the CAA',
              ],
              correctIndex: 1,
              explanation: 'Class D airspace requires an ATC clearance and established two-way radio communication before entry. You must call the relevant ATC unit, state your intentions, and receive an explicit clearance.',
            ),
            _QuizQuestion(
              question: 'Where is the authoritative source for all permanent UK aeronautical information, including airspace classifications?',
              options: [
                'SkyDemon app only',
                'UK AIP on AIS.org.uk',
                'ATIS broadcasts',
                'NOTAM bulletins',
              ],
              correctIndex: 1,
              explanation: 'The UK Aeronautical Information Publication (AIP) on AIS.org.uk is the authoritative reference. SkyDemon and other tools derive their data from it but the AIP is the primary source.',
            ),
            _QuizQuestion(
              question: 'A danger area is not listed as active at your planned crossing time. What should you do?',
              options: [
                'Fly through without further checks',
                'Only check the day before, not on the day',
                'Verify activation status via current NOTAMs and consider an alternative routing',
                'Danger areas never apply to VFR pilots',
              ],
              correctIndex: 2,
              explanation: 'Even if a danger area is not shown as active in the AIP schedule, you must check current NOTAMs on the day for ad hoc activation. If there is any doubt, route around it.',
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chapter 6: On the Day  (PREMIUM)
// ---------------------------------------------------------------------------

class _Chapter6Body extends StatelessWidget {
  const _Chapter6Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'ATIS at Departure and Destination',
          icon: Icons.radio_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'ATIS (Automatic Terminal Information Service) broadcasts a continuous loop of weather and aerodrome information on a dedicated frequency. Listen before departure and before arrival at your destination.',
              ),
              const SizedBox(height: 14),
              const _Body('What the ATIS gives you:'),
              const SizedBox(height: 8),
              const _Bullets(
                'QNH (altimeter setting for the aerodrome)\n'
                'Active runway\n'
                'Surface wind (direction and speed)\n'
                'Visibility and weather conditions\n'
                'Cloud base and type\n'
                'Temperature and dewpoint\n'
                'ATIS information code (e.g. "information Romeo")',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.info_outline_rounded,
                text: 'When you call ATC, confirm you have the current ATIS by quoting the information code: "...with information Romeo." If you have an old code, request an update.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Airways Clearances and Transiting Controlled Airspace',
          icon: Icons.flight_takeoff_rounded,
          child: const _Body(
            'If your route passes through Class D (or Class C) airspace, you must obtain a clearance before entry. Call the relevant ATC unit when you are approximately 10–15 minutes from the boundary, give your full call sign, position, level, intentions, and ATIS code.\n\nATC may give you a squawk code, a specific routing through the zone, level restrictions, or they may decline the transit. If declined, you must route around the controlled airspace. Plan an alternative routing in advance so you are not caught unprepared.\n\nIf transiting is planned and the zone is closed at the relevant time, note this before departure and file an alternative routing on your PLOG.',
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'In-Flight: Position Reports and Updating ETAs',
          icon: Icons.gps_fixed_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'Once airborne, work through your PLOG methodically:',
              ),
              const SizedBox(height: 14),
              const _Bullets(
                'At each waypoint, note your actual time (ATA) and compare with your ETA.\n'
                'If ATA differs from ETA by more than 2–3 minutes, recalculate subsequent ETAs before the next leg.\n'
                'Groundspeed checks: at the first waypoint, verify your actual GS against planned GS. If GS is lower than planned, your fuel burn per nm increases — check your fuel state accordingly.\n'
                'Give position reports to FIS (e.g. London Information) as requested, or proactively if you are uncertain of your position.\n'
                'Maintain a listening watch on 121.500 MHz at all times if you have a second radio available.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Diversion Decision Framework',
          icon: Icons.fork_right_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body(
                'The decision to divert is one of the most important judgements you will make as a VFR pilot. A good framework is to consider four factors:',
              ),
              const SizedBox(height: 14),
              const _Bullets(
                'Fuel — do you have enough to reach the destination with reserves intact? If fuel to destination minus fixed reserve falls below your minimum, divert now.\n'
                'Weather — is the weather at or ahead of you below your personal minima (typically 1,500 ft cloudbase, 5 km visibility for a student)? Continuing into deteriorating weather is the leading cause of fatal VFR accidents.\n'
                'Time — are you significantly behind schedule? Late arrival in deteriorating light raises risk. If you will arrive after legal last light, divert.\n'
                'Uncertainty — are you uncertain of your position and unable to establish it within a reasonable time? Apply the lost procedure and consider diverting to the nearest identified airfield.',
              ),
              const SizedBox(height: 14),
              const _Callout(
                icon: Icons.warning_amber_rounded,
                text: 'Diverting is not a failure. It is a planned decision made with full situational awareness. The accident record is full of pilots who continued when they should have diverted. It is empty of pilots who diverted safely.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Section(
          title: 'Post-Flight: Logging and Self-Debrief',
          icon: Icons.checklist_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Body('After every nav flight, complete the following:'),
              const SizedBox(height: 14),
              const _Bullets(
                'Log the flight: date, aircraft registration, route, total time, and flight conditions.\n'
                'Compare planned vs actual ETAs: were your groundspeed calculations accurate? Was there more wind than forecast?\n'
                'Note any airspace that caused confusion — check the chart and understand the boundaries for next time.\n'
                'Identify the moment on the flight where you felt least certain — what would you do differently in planning or execution?\n'
                'If you flew with an FIS, note their workload and how your position reports were received — did you give enough information clearly?\n'
                'Brief your next flight to address the weakest point in this one.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _QuizCard(
          questions: [
            _QuizQuestion(
              question: 'You planned to arrive at waypoint 2 at 14:32. You actually arrive at 14:36. What should you do?',
              options: [
                'Ignore it — 4 minutes is within acceptable margins',
                'Recalculate your remaining ETAs before continuing',
                'Declare a MAYDAY immediately',
                'Return to the departure airfield',
              ],
              correctIndex: 1,
              explanation: 'A 4-minute discrepancy suggests your actual groundspeed differs from planned. You must recalculate all subsequent ETAs and review your fuel state, as a lower GS means higher fuel burn per nm.',
            ),
            _QuizQuestion(
              question: 'What is the correct action when you enter deteriorating weather and your cloud base is dropping below your personal minima?',
              options: [
                'Continue and hope conditions improve',
                'Climb above the cloud',
                'Divert immediately to a suitable aerodrome',
                'Descend below the cloud to maintain VMC',
              ],
              correctIndex: 2,
              explanation: 'When weather deteriorates below your personal minima, divert. Continuing into IMC as a VFR-only pilot is illegal and extremely dangerous. Descending to stay below cloud in deteriorating visibility is a classic accident scenario.',
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
