// ATIS decoding practice screen — shows simulated UK ATIS broadcasts and
// quizzes the student on key decoded values.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/voice_service.dart';

// ---------------------------------------------------------------------------
// Static ATIS data
// ---------------------------------------------------------------------------

class _AtisExample {
  final String airfield;
  final String identifier;
  final String broadcast;

  // Correct answers
  final String runway;
  final String qnh;
  final String surfaceWind;
  final bool isVfrLegal; // true = VFR legal; false = not legal; null = marginal
  final bool? isMarginal;
  final String infoIdentifier;

  // Explanations shown after Check Answers
  final String runwayExplanation;
  final String qnhExplanation;
  final String windExplanation;
  final String vfrExplanation;
  final String identExplanation;

  const _AtisExample({
    required this.airfield,
    required this.identifier,
    required this.broadcast,
    required this.runway,
    required this.qnh,
    required this.surfaceWind,
    required this.isVfrLegal,
    this.isMarginal,
    required this.infoIdentifier,
    required this.runwayExplanation,
    required this.qnhExplanation,
    required this.windExplanation,
    required this.vfrExplanation,
    required this.identExplanation,
  });
}

const List<_AtisExample> _kAtisExamples = [
  _AtisExample(
    airfield: 'CRANFIELD',
    identifier: 'Alpha',
    broadcast:
        'This is Cranfield Information Alpha. Runway two-six in use. Surface wind two-six-zero degrees, one-five knots. Visibility ten kilometres or more. Few at one thousand eight hundred feet, scattered at three thousand feet. Temperature plus one-four. Dewpoint plus zero-eight. QNH one zero two-four hectopascals. No significant remarks. Advise Cranfield Information Alpha on first contact.',
    runway: '26',
    qnh: '1024',
    surfaceWind: '260/15',
    isVfrLegal: true,
    isMarginal: false,
    infoIdentifier: 'Alpha',
    runwayExplanation:
        'The ATIS states "Runway two-six in use", which is runway 26.',
    qnhExplanation:
        'QNH 1024 hPa is stated directly. Set this on your altimeter before departure.',
    windExplanation:
        'Surface wind 260 degrees at 15 knots. Roughly aligned with runway 26 — light headwind on departure.',
    vfrExplanation:
        'Visibility 10 km+, cloud base 1800 ft with FEW coverage — comfortably above VFR minima. Note SERA.5005: in Class G below 3,000 ft AMSL (or 1,000 ft AGL, whichever higher) the visibility minimum drops to 1,500 m provided you fly at/below 140 KIAS, in sight of the surface, and clear of cloud. Above that band you need 5 km and 1,500 m horizontal / 1,000 ft vertical cloud separation.',
    identExplanation:
        'The identifier is "Alpha" — you must report "information Alpha" on first contact with Cranfield.',
  ),
  _AtisExample(
    airfield: 'OXFORD',
    identifier: 'Bravo',
    broadcast:
        'This is Oxford Information Bravo. Runway one-niner in use. Surface wind two-zero-zero degrees, zero-eight knots. Visibility five kilometres. Broken at one thousand two hundred feet. Temperature plus one-one. Dewpoint plus zero-nine. QNH nine-niner-eight hectopascals. Light drizzle reported. Advise Oxford Information Bravo on first contact.',
    runway: '19',
    qnh: '998',
    surfaceWind: '200/08',
    isVfrLegal: false,
    isMarginal: true,
    infoIdentifier: 'Bravo',
    runwayExplanation:
        'The ATIS states "Runway one-niner in use", which is runway 19.',
    qnhExplanation:
        'QNH 998 hPa — below standard. Ensure your altimeter is set correctly; terrain clearance depends on this.',
    windExplanation:
        'Wind 200/08 — 20 degrees off runway 19, light crosswind component. Within limits for most training aircraft.',
    vfrExplanation:
        'Marginal — technically legal but high risk. Visibility 5 km satisfies the SERA.5005 upper-band minimum (you are likely above 1,000 ft AGL once airborne); below 3,000 ft AMSL / 1,000 ft AGL the visibility minimum can drop to 1,500 m at/below 140 KIAS, clear of cloud, in sight of surface. BKN at 1,200 ft is above the 1,000 ft below-cloud requirement. However, the low cloud base leaves minimal margin and light drizzle could reduce visibility further. Most instructors would advise against solo flight in these conditions.',
    identExplanation:
        'The identifier is "Bravo" — always pass the current information letter on first contact.',
  ),
  _AtisExample(
    airfield: 'TURWESTON',
    identifier: 'Charlie',
    broadcast:
        'This is Turweston Information Charlie. Runway two-one in use. Surface wind two-three-zero degrees, one-two knots. Visibility greater than ten kilometres. SKC. Temperature plus one-eight. Dewpoint plus zero-four. QNH one zero one-five hectopascals. No significant remarks. Advise Turweston Information Charlie on first contact.',
    runway: '21',
    qnh: '1015',
    surfaceWind: '230/12',
    isVfrLegal: true,
    isMarginal: false,
    infoIdentifier: 'Charlie',
    runwayExplanation:
        'The ATIS states "Runway two-one in use", which is runway 21.',
    qnhExplanation:
        'QNH 1015 hPa — very close to standard. Standard pressure is 1013.25 hPa.',
    windExplanation:
        'Wind 230/12 — roughly aligned with runway 21, light headwind. Good conditions.',
    vfrExplanation:
        'SKC (Sky Clear) and visibility 10 km+ — excellent VFR conditions, comfortably above SERA.5005 minimums in any Class G band.',
    identExplanation:
        'Information Charlie — pass "information Charlie" on first contact.',
  ),
  _AtisExample(
    airfield: 'WELLESBOURNE MOUNTFORD',
    identifier: 'Delta',
    broadcast:
        'This is Wellesbourne Information Delta. Runway two-seven in use. Surface wind zero-niner-zero degrees, two-zero knots, gusting two-eight. Visibility six kilometres. Overcast at eight hundred feet. Temperature plus zero-eight. Dewpoint plus zero-seven. QNH one zero zero-five hectopascals. Moderate turbulence below two thousand feet reported by departing traffic. Advise Wellesbourne Information Delta on first contact.',
    runway: '27',
    qnh: '1005',
    surfaceWind: '090/20G28',
    isVfrLegal: false,
    isMarginal: false,
    infoIdentifier: 'Delta',
    runwayExplanation:
        'The ATIS states "Runway two-seven in use", which is runway 27.',
    qnhExplanation:
        'QNH 1005 hPa — below standard. Note the significant deviation from 1013 hPa.',
    windExplanation:
        'Wind 090/20G28 — a direct crosswind on runway 27 at 20 knots gusting 28. Exceeds crosswind limits for most training aircraft. Consider delaying departure.',
    vfrExplanation:
        'Not VFR-legal at circuit height. Overcast at 800 ft means clear-of-cloud and 1,000 ft AGL clearance cannot be maintained simultaneously above the airfield (Wellesbourne elevation ~159 ft, so cloud base ~640 ft AGL). Combined with gusty crosswind and moderate turbulence — a clear no-go for student pilots.',
    identExplanation:
        'Information Delta — always report the current ATIS letter on first contact so ATC knows you have the latest information.',
  ),
  _AtisExample(
    airfield: 'COVENTRY',
    identifier: 'Echo',
    broadcast:
        'This is Coventry Information Echo. Runway zero-five in use. Surface wind zero-five-zero degrees, one-zero knots. Visibility eight kilometres, haze. Scattered at two thousand five hundred feet. Temperature plus two-two. Dewpoint plus one-five. QNH one zero one-one hectopascals. No significant remarks. Advise Coventry Information Echo on first contact.',
    runway: '05',
    qnh: '1011',
    surfaceWind: '050/10',
    isVfrLegal: true,
    isMarginal: false,
    infoIdentifier: 'Echo',
    runwayExplanation:
        'The ATIS states "Runway zero-five in use", which is runway 05.',
    qnhExplanation:
        'QNH 1011 hPa — just below standard. Set it precisely; a 2 hPa error gives roughly 60 ft of altimeter error.',
    windExplanation:
        'Wind 050/10 — closely aligned with runway 05, light headwind. Ideal conditions.',
    vfrExplanation:
        'VFR legal. Visibility 8 km comfortably exceeds the 5 km Class G minimum applicable above 3,000 ft AMSL / 1,000 ft AGL (and the 1,500 m low-level minimum at/below that band). SCATTERED at 2,500 ft gives plenty of cloud separation. Haze noted — keep a good lookout.',
    identExplanation:
        'Information Echo — pass on first contact. If ATIS has updated since you listened, ATC will give you the latest.',
  ),
  _AtisExample(
    airfield: 'GLOUCESTER',
    identifier: 'Foxtrot',
    broadcast:
        'This is Gloucester Information Foxtrot. Runway two-two in use. Surface wind two-five-zero degrees, two-five knots, gusting three-five. Visibility two kilometres, fog. Overcast at two hundred feet. Temperature plus zero-three. Dewpoint plus zero-three. QNH nine-niner-two hectopascals. ILS approach in use. Advise Gloucester Information Foxtrot on first contact.',
    runway: '22',
    qnh: '992',
    surfaceWind: '250/25G35',
    isVfrLegal: false,
    isMarginal: false,
    infoIdentifier: 'Foxtrot',
    runwayExplanation:
        'The ATIS states "Runway two-two in use", which is runway 22.',
    qnhExplanation:
        'QNH 992 hPa — very low. A significant depression is overhead. This is well below standard 1013 hPa.',
    windExplanation:
        'Wind 250/25G35 — strong gusting crosswind on runway 22. Well above crosswind limits for training aircraft.',
    vfrExplanation:
        'Absolutely not VFR-legal. Visibility 2 km in fog is above the 1,500 m low-level minimum on paper, but overcast at 200 ft means you cannot remain clear of cloud in sight of the surface. Even the relaxed low-level Class G rule (1,500 m vis at/below 140 KIAS, clear of cloud, in sight of surface) cannot be met. Instrument conditions. Do not depart VFR.',
    identExplanation:
        'Information Foxtrot — in IMC/IFR conditions this is even more critical as ATC needs confirmation you have current weather.',
  ),
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _AtisSessionState {
  final int currentIndex;
  final bool answered;
  final int sessionScore;
  final int sessionAttempts;

  const _AtisSessionState({
    this.currentIndex = 0,
    this.answered = false,
    this.sessionScore = 0,
    this.sessionAttempts = 0,
  });

  _AtisSessionState copyWith({
    int? currentIndex,
    bool? answered,
    int? sessionScore,
    int? sessionAttempts,
  }) {
    return _AtisSessionState(
      currentIndex: currentIndex ?? this.currentIndex,
      answered: answered ?? this.answered,
      sessionScore: sessionScore ?? this.sessionScore,
      sessionAttempts: sessionAttempts ?? this.sessionAttempts,
    );
  }
}

// ---------------------------------------------------------------------------
// ATIS Screen
// ---------------------------------------------------------------------------

class AtisScreen extends ConsumerStatefulWidget {
  const AtisScreen({super.key});

  @override
  ConsumerState<AtisScreen> createState() => _AtisScreenState();
}

class _AtisScreenState extends ConsumerState<AtisScreen> {
  _AtisSessionState _session = const _AtisSessionState();

  late final VoiceService _voice;
  bool _isSpeaking = false;

  // Answer controllers
  late TextEditingController _runwayCtrl;
  late TextEditingController _qnhCtrl;
  late TextEditingController _windCtrl;
  String? _vfrAnswer; // 'yes' | 'no' | 'marginal'
  late TextEditingController _identCtrl;

  @override
  void initState() {
    super.initState();
    _voice = VoiceService();
    _voice.addListener(_onVoiceChanged);
    _voice.init();
    _initControllers();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    setState(() => _isSpeaking = _voice.isSpeaking);
  }

  void _initControllers() {
    _runwayCtrl = TextEditingController();
    _qnhCtrl = TextEditingController();
    _windCtrl = TextEditingController();
    _identCtrl = TextEditingController();
    _vfrAnswer = null;
  }

  void _disposeControllers() {
    _runwayCtrl.dispose();
    _qnhCtrl.dispose();
    _windCtrl.dispose();
    _identCtrl.dispose();
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _voice.dispose();
    _disposeControllers();
    super.dispose();
  }

  _AtisExample get _current => _kAtisExamples[_session.currentIndex];

  Future<void> _readAtisAloud() async {
    if (_isSpeaking) {
      await _voice.stopSpeaking();
    } else {
      await _voice.speakAtcResponse(_current.broadcast);
    }
  }

  // ── Score a set of answers ───────────────────────────────────────────────

  int _scoreAnswers() {
    final ex = _current;
    int correct = 0;

    // Runway — strip leading zeros, case insensitive
    final runwayInput = _runwayCtrl.text.trim().replaceAll(RegExp(r'^0+'), '');
    final runwayCorrect = ex.runway.replaceAll(RegExp(r'^0+'), '');
    if (runwayInput.toLowerCase() == runwayCorrect.toLowerCase()) correct++;

    // QNH — numeric match
    final qnhInput = _qnhCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (qnhInput == ex.qnh) correct++;

    // Wind — flexible: accept e.g. "260/15" or "260 15" or "260 degrees 15"
    final windNorm = _normaliseWind(_windCtrl.text);
    final windCorrectNorm = _normaliseWind(ex.surfaceWind);
    if (windNorm == windCorrectNorm) correct++;

    // VFR
    if (_vfrAnswer != null) {
      final expectedVfr = ex.isVfrLegal
          ? 'yes'
          : (ex.isMarginal == true ? 'marginal' : 'no');
      if (_vfrAnswer == expectedVfr) correct++;
    }

    // Info identifier — case insensitive
    final identInput = _identCtrl.text.trim().toLowerCase();
    if (identInput == ex.infoIdentifier.toLowerCase()) correct++;

    return correct;
  }

  String _normaliseWind(String raw) {
    // Extract digits only, then take first 3 as direction, next 2 as speed
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 5) {
      return '${digits.substring(0, 3)}/${digits.substring(3, 5)}';
    }
    return digits.toLowerCase();
  }

  void _checkAnswers() {
    final score = _scoreAnswers();
    setState(() {
      _session = _session.copyWith(
        answered: true,
        sessionScore: _session.sessionScore + score,
        sessionAttempts: _session.sessionAttempts + 1,
      );
    });
  }

  void _nextAtis() {
    _voice.stopSpeaking();
    _disposeControllers();
    final nextIndex = (_session.currentIndex + 1) % _kAtisExamples.length;
    setState(() {
      _session = _session.copyWith(currentIndex: nextIndex, answered: false);
      _initControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = _current;
    final answered = _session.answered;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radio_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'ATIS Practice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        automaticallyImplyLeading: true,
        actions: [
          if (_session.sessionAttempts > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Score: ${_session.sessionScore}/${_session.sessionAttempts * 5}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          if (_voice.ttsReady)
            IconButton(
              onPressed: _readAtisAloud,
              icon: Icon(
                _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: 22,
                color: _isSpeaking ? AppColors.error : null,
              ),
              tooltip: _isSpeaking ? 'Stop' : 'Read ATIS aloud',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ATIS broadcast ─────────────────────────────────────────
            _AtisCard(key: ValueKey(ex.identifier), example: ex),
            const SizedBox(height: 24),

            // ── Questions ─────────────────────────────────────────────
            Text(
              'Decode the ATIS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),

            _QuestionField(
              label: '1. What runway is in use?',
              hint: 'e.g. 26',
              controller: _runwayCtrl,
              enabled: !answered,
              answered: answered,
              isCorrect: answered
                  ? _runwayCtrl.text
                          .trim()
                          .replaceAll(RegExp(r'^0+'), '')
                          .toLowerCase() ==
                      ex.runway
                          .replaceAll(RegExp(r'^0+'), '')
                          .toLowerCase()
                  : null,
              correctAnswer: ex.runway,
              explanation: ex.runwayExplanation,
            ),
            const SizedBox(height: 12),

            _QuestionField(
              label: '2. What is the QNH?',
              hint: 'e.g. 1024',
              controller: _qnhCtrl,
              enabled: !answered,
              keyboardType: TextInputType.number,
              answered: answered,
              isCorrect: answered
                  ? _qnhCtrl.text.trim().replaceAll(RegExp(r'\D'), '') ==
                      ex.qnh
                  : null,
              correctAnswer: '${ex.qnh} hPa',
              explanation: ex.qnhExplanation,
            ),
            const SizedBox(height: 12),

            _QuestionField(
              label: '3. What is the surface wind?',
              hint: 'e.g. 260/15',
              controller: _windCtrl,
              enabled: !answered,
              answered: answered,
              isCorrect: answered
                  ? _normaliseWind(_windCtrl.text) ==
                      _normaliseWind(ex.surfaceWind)
                  : null,
              correctAnswer: ex.surfaceWind,
              explanation: ex.windExplanation,
            ),
            const SizedBox(height: 12),

            // VFR multiple choice
            _VfrQuestion(
              selected: _vfrAnswer,
              enabled: !answered,
              answered: answered,
              expected: ex.isVfrLegal
                  ? 'yes'
                  : (ex.isMarginal == true ? 'marginal' : 'no'),
              explanation: ex.vfrExplanation,
              onChanged: (v) => setState(() => _vfrAnswer = v),
            ),
            const SizedBox(height: 12),

            _QuestionField(
              label:
                  '5. What information identifier do you pass on first contact?',
              hint: 'e.g. Alpha',
              controller: _identCtrl,
              enabled: !answered,
              answered: answered,
              isCorrect: answered
                  ? _identCtrl.text.trim().toLowerCase() ==
                      ex.infoIdentifier.toLowerCase()
                  : null,
              correctAnswer: ex.infoIdentifier,
              explanation: ex.identExplanation,
            ),
            const SizedBox(height: 28),

            // ── Action buttons ─────────────────────────────────────────
            if (!answered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checkAnswers,
                  child: const Text('Check Answers'),
                ),
              )
            else ...[
              // Score row
              _ScoreRow(
                score: _scoreAnswers(),
                total: 5,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _nextAtis,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next ATIS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ATIS card — broadcast text hidden by default; revealed on tap
// ---------------------------------------------------------------------------

class _AtisCard extends StatefulWidget {
  final _AtisExample example;
  const _AtisCard({super.key, required this.example});

  @override
  State<_AtisCard> createState() => _AtisCardState();
}

class _AtisCardState extends State<_AtisCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'INFO ${widget.example.identifier.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.example.airfield,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_revealed) ...[
            Text(
              'Listen to the ATIS using the speaker button above, then answer the questions below.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _revealed = true),
              child: Text(
                'Show transcript',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ] else ...[
            Text(
              widget.example.broadcast,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                height: 1.6,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _revealed = false),
              child: Text(
                'Hide transcript',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question field
// ---------------------------------------------------------------------------

class _QuestionField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final bool answered;
  final bool? isCorrect;
  final String correctAnswer;
  final String explanation;
  final TextInputType? keyboardType;

  const _QuestionField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
    required this.answered,
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    Color? borderColor;
    if (answered && isCorrect != null) {
      borderColor = isCorrect! ? AppColors.success : AppColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.onSurface, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: borderColor != null
                  ? BorderSide(color: borderColor, width: 1.5)
                  : const BorderSide(color: AppColors.dividerDark, width: 0.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: borderColor != null
                  ? BorderSide(color: borderColor, width: 1.5)
                  : const BorderSide(color: AppColors.dividerDark, width: 0.5),
            ),
            suffixIcon: answered && isCorrect != null
                ? Icon(
                    isCorrect!
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isCorrect! ? AppColors.success : AppColors.error,
                    size: 20,
                  )
                : null,
          ),
        ),
        if (answered) ...[
          const SizedBox(height: 6),
          if (isCorrect == false)
            Text(
              'Correct: $correctAnswer',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// VFR multiple choice question (Q4)
// ---------------------------------------------------------------------------

class _VfrQuestion extends StatelessWidget {
  final String? selected;
  final bool enabled;
  final bool answered;
  final String expected; // 'yes' | 'no' | 'marginal'
  final String explanation;
  final ValueChanged<String?> onChanged;

  const _VfrQuestion({
    required this.selected,
    required this.enabled,
    required this.answered,
    required this.expected,
    required this.explanation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. Is the weather VFR-legal?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _VfrChip(
              label: 'Yes',
              value: 'yes',
              selected: selected,
              expected: expected,
              answered: answered,
              enabled: enabled,
              onTap: enabled ? () => onChanged('yes') : null,
            ),
            const SizedBox(width: 8),
            _VfrChip(
              label: 'Marginal',
              value: 'marginal',
              selected: selected,
              expected: expected,
              answered: answered,
              enabled: enabled,
              onTap: enabled ? () => onChanged('marginal') : null,
            ),
            const SizedBox(width: 8),
            _VfrChip(
              label: 'No',
              value: 'no',
              selected: selected,
              expected: expected,
              answered: answered,
              enabled: enabled,
              onTap: enabled ? () => onChanged('no') : null,
            ),
          ],
        ),
        if (answered) ...[
          const SizedBox(height: 8),
          if (selected != expected)
            Text(
              'Correct: ${expected[0].toUpperCase()}${expected.substring(1)}',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _VfrChip extends StatelessWidget {
  final String label;
  final String value;
  final String? selected;
  final String expected;
  final bool answered;
  final bool enabled;
  final VoidCallback? onTap;

  const _VfrChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.expected,
    required this.answered,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;

    Color borderColor = AppColors.divider;
    Color bgColor = AppColors.surfaceVariant;
    Color textColor = AppColors.onSurface;

    if (answered) {
      if (value == expected) {
        borderColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
      } else if (isSelected && value != expected) {
        borderColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.10);
        textColor = AppColors.error;
      }
    } else if (isSelected) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.12);
      textColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score row
// ---------------------------------------------------------------------------

class _ScoreRow extends StatelessWidget {
  final int score;
  final int total;
  const _ScoreRow({required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (score / total * 100).round();
    final colour = pct >= 80
        ? AppColors.success
        : pct >= 60
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            pct >= 80
                ? Icons.check_circle_rounded
                : pct >= 60
                    ? Icons.warning_amber_rounded
                    : Icons.cancel_rounded,
            color: colour,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$score / $total correct',
              style: TextStyle(
                color: colour,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              color: colour,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
