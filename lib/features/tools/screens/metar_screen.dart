// METAR training screen — live weather fetch + 5-question graded session.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/providers/metar_provider.dart';
import 'package:flight_path/shared/services/avwx_service.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

class MetarScreen extends ConsumerStatefulWidget {
  const MetarScreen({super.key});

  @override
  ConsumerState<MetarScreen> createState() => _MetarScreenState();
}

class _MetarScreenState extends ConsumerState<MetarScreen> {
  final _textController = TextEditingController();

  // Tracks which question is currently awaiting answer vs. showing result.
  // null = question is active (awaiting answer).
  // non-null = result is being shown for that question index.
  int? _pendingResultIndex;

  MetarAnswerResult? _lastResult;

  @override
  void initState() {
    super.initState();
    // Trigger initial fetch after the first frame so Riverpod state is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(metarProvider.notifier).fetchMetar();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ── Paywall helper ─────────────────────────────────────────────────────────

  Future<void> _showPaywall() async {
    final purchased = await showPremiumPaywall(
      context,
      source: 'metar_daily_limit',
    );
    if (purchased && mounted) {
      // Re-trigger fetch now that the user is premium.
      ref.read(metarProvider.notifier).fetchMetar();
    }
  }

  // ── Answer flow ────────────────────────────────────────────────────────────

  void _submitAnswer(String answer) {
    if (answer.trim().isEmpty) return;
    final result =
        ref.read(metarProvider.notifier).submitAnswer(answer.trim());
    setState(() {
      _lastResult = result;
      _pendingResultIndex = ref.read(metarProvider).questionIndex;
    });
    _textController.clear();
    FocusScope.of(context).unfocus();
  }

  void _submitChoiceAnswer(String choice) => _submitAnswer(choice);

  void _advanceToNextQuestion() {
    setState(() {
      _pendingResultIndex = null;
      _lastResult = null;
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metarProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Paywall trigger — show bottom sheet once.
    if (state.paywallRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPaywall());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('METAR Training'),
        actions: [
          _AirfieldPicker(
            currentIcao: state.icao,
            onChanged: (icao) {
              setState(() {
                _pendingResultIndex = null;
                _lastResult = null;
              });
              ref.read(metarProvider.notifier).selectIcao(icao);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: state.isLoading
            ? _buildLoader(state.icao)
            : state.apiKeyMissing
                ? _buildApiKeyMissingCard(isDark)
                : state.fetchError
                    ? _buildFetchErrorCard(state.icao)
                    : state.rawMetar != null
                        ? _buildSessionBody(state, isDark)
                        : const SizedBox.shrink(),
      ),
    );
  }

  // ── Loader ─────────────────────────────────────────────────────────────────

  Widget _buildLoader(String icao) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Fetching live METAR for $icao...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ── API key missing ────────────────────────────────────────────────────────

  Widget _buildApiKeyMissingCard(bool isDark) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            borderColor: AppColors.warning,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Live METAR fetch is not available in this build. '
                    'Practise decoding the example below — it uses real-world format.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _MetarCard(metar: kExampleMetar, isDark: isDark),
          const SizedBox(height: AppSpacing.cardGap),
          _ExampleMetarBreakdown(isDark: isDark),
        ],
      ),
    );
  }

  // ── Fetch error ────────────────────────────────────────────────────────────

  Widget _buildFetchErrorCard(String icao) {
    return Center(
      child: Padding(
        padding: AppSpacing.pageHorizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Could not fetch METAR for $icao.',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(metarProvider.notifier).fetchMetar(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Session body ───────────────────────────────────────────────────────────

  Widget _buildSessionBody(MetarSessionState state, bool isDark) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session counter chip
          _SessionChip(
            dailyCount: state.dailySessionCount,
          ),
          const SizedBox(height: AppSpacing.cardGap),

          // Raw METAR card
          _MetarCard(metar: state.rawMetar!, isDark: isDark),
          const SizedBox(height: AppSpacing.sectionGap),

          // Pending result for the last question — show before score card.
          if (_pendingResultIndex != null &&
              _lastResult != null &&
              state.sessionComplete) ...[
            _QuestionProgress(
              current: kMetarQuestions.length,
              total: kMetarQuestions.length,
            ),
            const SizedBox(height: AppSpacing.cardGap),
            _AnswerFeedback(
              result: _lastResult!,
              isFinalQuestion: true,
              onNext: _advanceToNextQuestion,
            ),

          // Session complete — score + next button.
          ] else if (state.sessionComplete) ...[
            _ScoreCard(state: state),
            const SizedBox(height: AppSpacing.cardGap),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _pendingResultIndex = null;
                  _lastResult = null;
                });
                ref.read(metarProvider.notifier).nextMetar();
              },
              child: const Text('Try another METAR'),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _AnswersSummary(answers: state.answers),

          ] else ...[
            // Progress indicator
            _QuestionProgress(
              current: state.questionIndex + 1,
              total: kMetarQuestions.length,
            ),
            const SizedBox(height: AppSpacing.cardGap),

            // Question card — show result or prompt
            if (_pendingResultIndex != null && _lastResult != null) ...[
              _AnswerFeedback(
                result: _lastResult!,
                onNext: _advanceToNextQuestion,
                isFinalQuestion: false,
              ),
            ] else ...[
              _QuestionCard(
                question: kMetarQuestions[state.questionIndex],
                controller: _textController,
                onSubmitText: _submitAnswer,
                onSubmitChoice: _submitChoiceAnswer,
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AirfieldPicker extends StatelessWidget {
  final String currentIcao;
  final ValueChanged<String> onChanged;

  const _AirfieldPicker({
    required this.currentIcao,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: AvwxService.ukTrainingAirfields.contains(currentIcao)
            ? currentIcao
            : AvwxService.ukTrainingAirfields.first,
        icon: const Icon(Icons.arrow_drop_down_rounded),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
        dropdownColor: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: AvwxService.ukTrainingAirfields
            .map(
              (icao) => DropdownMenuItem(
                value: icao,
                child: Text(icao),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MetarCard extends StatelessWidget {
  final String metar;
  final bool isDark;

  const _MetarCard({required this.metar, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'RAW METAR',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            metar,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.6,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleMetarBreakdown extends StatelessWidget {
  final bool isDark;

  const _ExampleMetarBreakdown({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decoded',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          ...kExampleMetarParsed.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      e.key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final int dailyCount;

  const _SessionChip({required this.dailyCount});

  @override
  Widget build(BuildContext context) {
    final remaining = (5 - dailyCount).clamp(0, 5);
    final text = remaining > 0
        ? '$remaining free session${remaining == 1 ? '' : 's'} remaining today'
        : 'Free daily limit reached — upgrade for unlimited sessions';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: remaining > 0
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: remaining > 0 ? AppColors.primary : AppColors.warning,
            ),
      ),
    );
  }
}

class _QuestionProgress extends StatelessWidget {
  final int current;
  final int total;

  const _QuestionProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question $current of $total',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              '${((current / total) * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: current / total,
            minHeight: 4,
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final MetarQuestion question;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitText;
  final ValueChanged<String> onSubmitChoice;

  const _QuestionCard({
    required this.question,
    required this.controller,
    required this.onSubmitText,
    required this.onSubmitChoice,
  });

  bool get _isChoiceOnly =>
      question.choices.isNotEmpty &&
      question.id == MetarQuestionId.vfrLegal;

  bool get _hasMixedChoices =>
      question.choices.isNotEmpty &&
      question.id == MetarQuestionId.cloudBase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),

          if (_isChoiceOnly) ...[
            // Pure multiple-choice (VFR legal question)
            Row(
              children: question.choices
                  .map(
                    (c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () => onSubmitChoice(c),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                          ),
                          child: Text(c),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else if (_hasMixedChoices) ...[
            // Cloud base: quick-select chips + optional free text
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: question.choices
                  .where((c) => c != 'Enter value')
                  .map(
                    (c) => ActionChip(
                      label: Text(c),
                      onPressed: () => onSubmitChoice(c),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _TextInputRow(
              controller: controller,
              hint: 'e.g. BKN018 or 1800ft',
              onSubmit: onSubmitText,
            ),
          ] else ...[
            // Free-text input
            _TextInputRow(
              controller: controller,
              hint: _hintFor(question.id),
              onSubmit: onSubmitText,
            ),
          ],
        ],
      ),
    );
  }

  String _hintFor(MetarQuestionId id) {
    switch (id) {
      case MetarQuestionId.wind:
        return 'e.g. 270° at 15 kt';
      case MetarQuestionId.visibility:
        return 'e.g. 9999 or 4000m';
      case MetarQuestionId.cloudBase:
        return 'e.g. BKN018 or SKC';
      case MetarQuestionId.qnh:
        return 'e.g. 1013 hPa';
      case MetarQuestionId.vfrLegal:
        return 'Yes / No / Marginal';
    }
  }
}

class _TextInputRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmit;

  const _TextInputRow({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: false,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
            decoration: InputDecoration(
              hintText: hint,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => onSubmit(controller.text),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(72, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Check'),
        ),
      ],
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  final MetarAnswerResult result;
  final VoidCallback onNext;
  final bool isFinalQuestion;

  const _AnswerFeedback({
    required this.result,
    required this.onNext,
    required this.isFinalQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = result.isCorrect;
    final accentColor = isCorrect ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Correct / Incorrect badge
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accentColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Correct answer
          if (!isCorrect) ...[
            Text(
              'Answer:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              result.correctAnswer,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
          ],

          // Explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              result.explanation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 16),

          // Next button
          ElevatedButton(
            onPressed: onNext,
            child: Text(isFinalQuestion ? 'See results' : 'Next question'),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final MetarSessionState state;

  const _ScoreCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final correct = state.correctCount;
    final total = state.totalAnswered;
    final pct = total > 0 ? (correct / total * 100).round() : 0;

    Color scoreColor;
    String label;
    if (pct >= 80) {
      scoreColor = AppColors.success;
      label = 'Well done';
    } else if (pct >= 60) {
      scoreColor = AppColors.warning;
      label = 'Good effort';
    } else {
      scoreColor = AppColors.error;
      label = 'Keep practising';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '$correct / $total',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scoreColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% correct',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scoreColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _AnswersSummary extends StatelessWidget {
  final List<MetarAnswerResult> answers;

  const _AnswersSummary({required this.answers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session review',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...answers.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a.isCorrect
                      ? Icons.check_circle_outline_rounded
                      : Icons.highlight_off_rounded,
                  size: 18,
                  color: a.isCorrect ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kMetarQuestions
                        .firstWhere((q) => q.id == a.questionId)
                        .prompt
                        .split('\n')
                        .first,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _InfoCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: child,
    );
  }
}
