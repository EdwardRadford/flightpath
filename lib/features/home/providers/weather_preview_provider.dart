// Weather preview provider — fetches and caches weather data for the home
// screen compact weather card.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/services/weather_service.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

// ---------------------------------------------------------------------------
// Weather preview state
// ---------------------------------------------------------------------------

/// Holds cached weather data plus metadata for the home screen preview card.
class WeatherPreviewState {
  final WeatherData? data;
  final bool loading;
  final String? error;
  final DateTime? fetchedAt;

  const WeatherPreviewState({
    this.data,
    this.loading = false,
    this.error,
    this.fetchedAt,
  });

  WeatherPreviewState copyWith({
    WeatherData? data,
    bool? loading,
    String? error,
    DateTime? fetchedAt,
  }) {
    return WeatherPreviewState(
      data: data ?? this.data,
      loading: loading ?? this.loading,
      error: error,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class WeatherPreviewNotifier extends StateNotifier<WeatherPreviewState> {
  WeatherPreviewNotifier(this._ref)
      : super(const WeatherPreviewState()) {
    _autoFetch();
  }

  final Ref _ref;
  final WeatherService _service = WeatherService();

  /// Cache duration — avoid hitting the Cloud Function too often.
  static const _cacheDuration = Duration(minutes: 15);

  /// Automatically fetch weather for the user's airfield on first load.
  Future<void> _autoFetch() async {
    final user = _ref.read(appUserProvider).valueOrNull;
    final icao = user?.airfieldIcao;
    if (icao == null || icao.isEmpty) return;
    await fetch(icao);
  }

  /// Fetches weather for [icaoCode], respecting the cache window.
  Future<void> fetch(String icaoCode) async {
    // Skip if still within cache window.
    if (state.fetchedAt != null &&
        DateTime.now().difference(state.fetchedAt!) < _cacheDuration &&
        state.data != null) {
      return;
    }

    state = state.copyWith(loading: true, error: null);

    try {
      final data = await _service.getWeatherForAirfield(icaoCode);
      state = WeatherPreviewState(
        data: data,
        loading: false,
        fetchedAt: DateTime.now(),
      );
    } on WeatherServiceException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load weather',
      );
    }
  }

  /// Force refresh, ignoring cache.
  Future<void> refresh(String icaoCode) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _service.getWeatherForAirfield(icaoCode);
      state = WeatherPreviewState(
        data: data,
        loading: false,
        fetchedAt: DateTime.now(),
      );
    } on WeatherServiceException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load weather',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final weatherPreviewProvider =
    StateNotifierProvider<WeatherPreviewNotifier, WeatherPreviewState>(
  (ref) => WeatherPreviewNotifier(ref),
);
