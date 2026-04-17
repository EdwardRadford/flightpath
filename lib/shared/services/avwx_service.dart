// AVWX REST API service — fetches live METAR strings for a given ICAO code.
// API key is supplied at compile time via --dart-define=AVWX_API_KEY=<token>.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// API key supplied at compile time. Build/run with:
///   --dart-define=AVWX_API_KEY=your_token
const String _apiKey = String.fromEnvironment('AVWX_API_KEY', defaultValue: '');

/// Fetches live METAR data from the AVWX REST API.
///
/// All methods are instance methods so the service can be injected or mocked
/// in tests. Use [avwxServiceProvider] (defined in metar_provider.dart) to
/// obtain a singleton via Riverpod.
class AvwxService {
  static const String _baseUrl = 'https://avwx.rest/api';

  /// Common UK training airfields used to seed the airfield picker.
  static const List<String> ukTrainingAirfields = [
    'EGTC', // Cranfield
    'EGBT', // Turweston
    'EGBJ', // Gloucestershire
    'EGBO', // Halfpenny Green
    'EGBP', // Cotswold
    'EGFF', // Cardiff Wales
    'EGHH', // Bournemouth
    'EGTE', // Exeter
    'EGHI', // Southampton
    'EGKA', // Shoreham
    'EGKB', // Biggin Hill
    'EGLF', // Farnborough
    'EGMD', // Lydd
    'EGNH', // Blackpool
    'EGNJ', // Humberside
    'EGNO', // Warton
    'EGNR', // Hawarden
    'EGNT', // Newcastle
    'EGPB', // Sumburgh
    'EGPD', // Aberdeen Dyce
    'EGPF', // Glasgow
    'EGPH', // Edinburgh
    'EGPK', // Prestwick
    'EGTT', // London FIR (VOLMET reference)
    'EGUB', // Benson
  ];

  /// Fetches the raw METAR string for [icao] from AVWX.
  ///
  /// Returns the raw METAR string on success (e.g. "METAR EGTC 121150Z ...").
  /// Returns `null` on network error or non-200 HTTP response so callers can
  /// show an error state without crashing.
  ///
  /// Throws [StateError] immediately if [AVWX_API_KEY] was not set at build
  /// time — this is intentional loud misconfiguration, not a recoverable error.
  Future<String?> fetchMetar(String icao) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'AVWX_API_KEY not configured. '
        'Pass --dart-define=AVWX_API_KEY=<token> when building or running.',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl/metar/${icao.toUpperCase()}?format=json',
    );

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Token $_apiKey');
      final response = await request.close();

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'AvwxService: HTTP ${response.statusCode} for $icao',
          );
        }
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final raw = json['raw'] as String?;

      if (raw == null || raw.isEmpty) {
        if (kDebugMode) debugPrint('AvwxService: empty raw field for $icao');
        return null;
      }

      return raw;
    } catch (e) {
      if (kDebugMode) debugPrint('AvwxService: error fetching $icao — $e');
      return null;
    } finally {
      client?.close();
    }
  }
}
