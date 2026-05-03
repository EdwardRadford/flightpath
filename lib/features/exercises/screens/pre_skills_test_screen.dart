import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';

class PreSkillsTestScreen extends ConsumerStatefulWidget {
  const PreSkillsTestScreen({super.key});

  @override
  ConsumerState<PreSkillsTestScreen> createState() => _PreSkillsTestScreenState();
}

class _PreSkillsTestScreenState extends ConsumerState<PreSkillsTestScreen> {
  bool _marking = false;
  bool _marked = false;

  Future<void> _markReady() async {
    if (_marking || _marked) return;
    setState(() => _marking = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'skills_test_ready_at': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) setState(() => _marked = true);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Skills Test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader('What the examiner checks'),
          const SizedBox(height: 12),
          _bulletItem(cs, 'General handling — climb, level, descent, turns to specified headings'),
          _bulletItem(cs, 'Stalling — recognition and recovery at all flap settings'),
          _bulletItem(cs, 'Forced landing without power — field selection, approach, go-around decision'),
          _bulletItem(cs, 'PFL — simulated engine failure on take-off (below safety height)'),
          _bulletItem(cs, 'Navigation — track keeping, timing, altimeter setting, diversion'),
          _bulletItem(cs, 'Circuit — crosswind, flapless, and a precision approach'),
          _bulletItem(cs, 'R/T — correct phraseology, read-backs, frequency changes'),
          const SizedBox(height: 28),
          _SectionHeader('Top reasons students fail'),
          const SizedBox(height: 12),
          _bulletItem(cs, 'Lookout — examiners cite this most often. Systematic scan on every turn.'),
          _bulletItem(cs, 'Altitude and heading tolerance — CAA standard is ±150 ft, ±10°. Know it. Fly it.'),
          _bulletItem(cs, 'Navigation — late fixes, wrong altimeter setting, poor fuel awareness.'),
          _bulletItem(cs, 'Talk-through — not narrating decisions in the forced landing exercise.'),
          _bulletItem(cs, 'Rushing — task-saturated students rush approaches and skip checks.'),
          const SizedBox(height: 28),
          _SectionHeader('The day before'),
          const SizedBox(height: 12),
          _paragraph(cs,
              'Brief the route properly. Check NOTAMs and weather. Lay out everything you need the night before — charts, log, licences. Get to bed early.'),
          const SizedBox(height: 28),
          _SectionHeader('Morning of the test'),
          const SizedBox(height: 12),
          _paragraph(cs,
              'Arrive 30 minutes early. Walk around the aircraft yourself before the examiner arrives. Check fuel and oil with your own eyes.'),
          const SizedBox(height: 28),
          _SectionHeader('In the cockpit'),
          const SizedBox(height: 12),
          _paragraph(cs,
              'Lookout, talk through your decisions, fly the aircraft. The examiner is on your side. If something goes wrong, acknowledge it and continue.'),
          const SizedBox(height: 32),
          if (!_marked)
            Semantics(
              label: 'Mark as ready for skills test',
              button: true,
              child: ElevatedButton(
                onPressed: _marking ? null : _markReady,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _marking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mark as ready'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Readiness confirmed. Good luck.',
                style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _SectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
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
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.6),
    );
  }
}
