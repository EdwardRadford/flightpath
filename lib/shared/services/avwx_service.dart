// AVWX METAR service — fetches live METAR strings via the `getWeather`
// Firebase Cloud Function. The AVWX API key is held server-side so it is
// never shipped inside the app binary.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Thrown when AVWX confirms the station exists but has no current METAR.
/// Distinct from a network error — the station simply doesn't publish reports.
class NoMetarDataException implements Exception {
  final String icao;
  const NoMetarDataException(this.icao);

  @override
  String toString() => 'NoMetarDataException: $icao does not publish live METARs';
}

/// Fetches live METAR data via the `getWeather` Firebase Cloud Function.
///
/// All methods are instance methods so the service can be injected or mocked
/// in tests. Use [avwxServiceProvider] (defined in metar_provider.dart) to
/// obtain a singleton via Riverpod.
class AvwxService {
  /// Cloud Function instance targeting the `europe-west2` region where
  /// `getWeather` is deployed.
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );

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

  /// Fetches the raw METAR string for [icao] via the `getWeather` Cloud Function.
  ///
  /// Returns the raw METAR string on success (e.g. "METAR EGTC 121150Z ...").
  /// Returns `null` on a generic fetch failure so callers can show an error
  /// state without crashing.
  ///
  /// Throws [NoMetarDataException] when the station exists but doesn't publish
  /// current METARs (Cloud Function returned `not-found`).
  Future<String?> fetchMetar(String icao) async {
    final sanitised = icao.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}$').hasMatch(sanitised)) {
      if (kDebugMode) {
        debugPrint('AvwxService: invalid ICAO "$icao"');
      }
      return null;
    }

    try {
      final callable = _functions.httpsCallable(
        'getWeather',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call({'icaoCode': sanitised});

      final data = result.data;
      if (data is! Map) {
        if (kDebugMode) {
          debugPrint('AvwxService: unexpected response shape for $sanitised');
        }
        return null;
      }

      final raw = data['raw_metar'];
      if (raw is! String || raw.isEmpty) {
        if (kDebugMode) {
          debugPrint('AvwxService: empty raw_metar for $sanitised');
        }
        return null;
      }
      return raw;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw NoMetarDataException(sanitised);
      }
      if (kDebugMode) {
        debugPrint('AvwxService: Functions error ${e.code} for $sanitised — ${e.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('AvwxService: error fetching $sanitised — $e');
      return null;
    }
  }
}
