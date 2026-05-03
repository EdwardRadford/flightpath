import 'package:flutter/foundation.dart';

class LogBufferService {
  static const int _maxLines = 50;
  static final List<String> _buffer = [];

  static void log(String message) {
    _buffer.add('[${DateTime.now().toIso8601String()}] $message');
    if (_buffer.length > _maxLines) {
      _buffer.removeAt(0);
    }
    debugPrint(message);
  }

  static List<String> get recentLogs => List.unmodifiable(_buffer);
}
