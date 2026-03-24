/// Utility for sanitising user text input before saving to Firestore or
/// sending to external APIs.
///
/// All text fields should be passed through [sanitise] before persistence.
class InputSanitiser {
  InputSanitiser._(); // prevent instantiation

  /// Trims whitespace, removes ASCII/Unicode control characters (except
  /// newline and tab), and enforces [maxLength].
  ///
  /// Returns the cleaned string, or an empty string if [input] is null.
  static String sanitise(String? input, {required int maxLength}) {
    if (input == null) return '';

    // Trim leading/trailing whitespace.
    var result = input.trim();

    // Remove control characters (C0 + C1) except newline (\n) and tab (\t).
    // This strips \x00-\x08, \x0B-\x0C, \x0E-\x1F, \x7F, and \x80-\x9F.
    result = result.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]'),
      '',
    );

    // Strip HTML/script tags to prevent XSS if content is ever rendered
    // in a WebView or similar context.
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    // Enforce maximum length.
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Preset limits — keep in sync with the security audit requirements.
  // ---------------------------------------------------------------------------

  /// Max chars for short text fields (flight school, ICAO, exercise notes).
  static const int maxShort = 500;

  /// Max chars for reflection / instructor comments / schedule notes.
  static const int maxMedium = 1000;

  /// Max chars for AI chat messages.
  static const int maxChat = 2000;

  /// Max chars for display name.
  static const int maxName = 100;
}
