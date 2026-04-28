// Voice service — wraps flutter_tts and speech_to_text for RT Practice.
// Designed to degrade gracefully: if either engine fails to initialise,
// the rest of the feature still works as text-only.
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

// ---------------------------------------------------------------------------
// VoiceService
// ---------------------------------------------------------------------------

class VoiceService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _ttsReady = false;
  bool _sttReady = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  double _speechRate = 0.45;

  bool get ttsReady => _ttsReady;
  bool get sttReady => _sttReady;
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Call once from the owning widget's [initState].
  /// Failures are swallowed so the screen still loads as text-only.
  Future<void> init() async {
    await Future.wait([_initTts(), _initStt()]);
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-GB');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((_) {
        _isSpeaking = false;
        notifyListeners();
      });

      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
    notifyListeners();
  }

  Future<void> _initStt() async {
    try {
      _sttReady = await _stt.initialize(
        onError: (_) {
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          // 'done' and 'notListening' both signal that recognition has ended
          if (status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus) {
            _isListening = false;
            notifyListeners();
          }
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    notifyListeners();
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  /// Updates the TTS speech rate and applies it to the engine immediately.
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    if (_ttsReady) {
      try {
        await _tts.setSpeechRate(rate);
      } catch (_) {
        debugPrint('VoiceService: $_');
      }
    }
  }

  /// Speaks [text] via TTS using en-GB at the current speech rate.
  /// Stops any current speech first. No-ops if TTS is not ready.
  Future<void> speakAtcResponse(String text) async {
    if (!_ttsReady || text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Stops current TTS playback.
  Future<void> stopSpeaking() async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
    } catch (_) {
      debugPrint('VoiceService: $_');
    }
    _isSpeaking = false;
    notifyListeners();
  }

  // ── STT ────────────────────────────────────────────────────────────────────

  /// Starts listening and streams partial results via [onResult].
  /// Automatically stops after 3 s of silence (pauseFor) or 30 s total.
  /// No-ops if STT is not ready.
  Future<void> startListening(Function(String) onResult) async {
    if (!_sttReady || _isListening) return;
    try {
      _isListening = true;
      notifyListeners();

      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_GB',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (_) {
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stops listening early (e.g. user taps cancel).
  Future<void> stopListening() async {
    if (!_sttReady) return;
    try {
      await _stt.stop();
    } catch (_) {
      debugPrint('VoiceService: $_');
    }
    _isListening = false;
    notifyListeners();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _tts.stop();
    if (_isListening) _stt.stop();
    super.dispose();
  }
}
