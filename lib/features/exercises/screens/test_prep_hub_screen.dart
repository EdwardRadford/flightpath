import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

class TestPrepHubScreen extends ConsumerStatefulWidget {
  const TestPrepHubScreen({super.key});

  @override
  ConsumerState<TestPrepHubScreen> createState() => _TestPrepHubScreenState();
}

class _TestPrepHubScreenState extends ConsumerState<TestPrepHubScreen> {
  // Persisted checklist state — keyed by date so it resets daily
  final List<bool> _checklist = [false, false, false];
  static final List<String> _checklistItems = [
    'Full mock skills test — end-to-end, instructor plays examiner',
    'Run pre-flight preparation independently (weather, mass and balance, performance)',
    'PFL drilling — field selection and key positions across varied terrain',
  ];
  String _prefsKey = '';

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _prefsKey = 'test_prep_checklist_$today';
    final saved = prefs.getStringList(_prefsKey) ?? [];
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _checklist.length; i++) {
        _checklist[i] = saved.length > i && saved[i] == '1';
      }
    });
  }

  Future<void> _toggleCheck(int i) async {
    setState(() => _checklist[i] = !_checklist[i]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, _checklist.map((v) => v ? '1' : '0').toList());
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;

    int? daysLeft;
    userAsync.whenData((user) {
      if (user?.skillsTestDate != null) {
        daysLeft = user!.skillsTestDate!.difference(DateTime.now()).inDays;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(daysLeft != null
            ? 'Skills test in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}'
            : 'Test prep'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Final 7 days checklist
          _sectionHeader(cs, 'Final 7 days'),
          const SizedBox(height: 12),
          ...List.generate(_checklistItems.length, (i) {
            return Semantics(
              label: _checklistItems[i],
              checked: _checklist[i],
              button: true,
              child: GestureDetector(
                onTap: () => _toggleCheck(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: _checklist[i]
                        ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _checklist[i]
                            ? Icons.check_circle_outline_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: _checklist[i]
                            ? AppColors.primary
                            : cs.onSurface.withValues(alpha: 0.4),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _checklistItems[i],
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            height: 1.5,
                            decoration: _checklist[i]
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 28),

          // Top 5 reasons people fail
          _sectionHeader(cs, 'Top reasons students fail'),
          const SizedBox(height: 12),
          _bulletItem(cs, 'Practice forced landing (PFL) — poor field selection and final-turn geometry. Most commonly cited by examiners.'),
          _bulletItem(cs, 'Navigation — losing situational awareness, micro-navigating instead of maintaining the lookout cycle.'),
          _bulletItem(cs, 'R/T errors — wrong phraseology, failing to action readbacks, wrong runway response.'),
          _bulletItem(cs, 'Pre-flight preparation — candidates underestimate the oral phase; incomplete weather, mass-balance, or performance work.'),
          _bulletItem(cs, 'EFATO response — hesitation or attempted turn-back at low level below safety altitude.'),

          const SizedBox(height: 28),

          // Pre-test ritual (day before)
          if (daysLeft != null && daysLeft! <= 1) ...[
            _sectionHeader(cs, 'Tomorrow is the day'),
            const SizedBox(height: 12),
            Text(
              'Three things to remember: lookout, talk through your decisions, fly the aircraft. The examiner is on your side.',
              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title) {
    return Text(
      title,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _bulletItem(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
              text,
              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
