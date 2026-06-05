import 'dart:async' show StreamController;
import 'dart:developer' as developer;

import 'preferences.dart';
import 'preferences_repository.dart';
import 'preferences_storage.dart';

/// Single source of truth for user [Preferences]: loads them at startup,
/// persists edits through [PreferencesRepository], and emits the new
/// snapshot on [stream] so [PreferencesScope] rebuilds listeners.
///
/// Save failures are non-fatal — the in-memory value is kept and emitted
/// so the current session stays consistent; the old value is restored on
/// next launch.
class PreferencesService {
  PreferencesService._(this._repository, this._current);

  final PreferencesRepository _repository;
  final _controller = StreamController<Preferences>.broadcast();
  Preferences _current;

  /// Constructs the service asynchronously, loading the initial
  /// [Preferences] from disk. [supportedCodes] bounds locale resolution
  /// (device locale → first supported → `en`).
  static Future<PreferencesService> create({
    required List<String> supportedCodes,
  }) async {
    final repository = PreferencesRepository(PreferencesStorage());
    final current = await repository.load(supportedCodes);
    // Normalise the JSON blob on disk after each load: ensures a one-shot
    // schema migration applied inside [load] (e.g. v1→v2 fontId reset)
    // is persisted so it does not re-run on every launch. Save failures
    // are swallowed for the same reason as in [update].
    try {
      await repository.save(current);
    } catch (e, st) {
      developer.log(
        'Failed to persist normalised preferences after load',
        error: e,
        stackTrace: st,
        name: 'PreferencesService',
      );
    }
    return PreferencesService._(repository, current);
  }

  /// Broadcast stream of [Preferences] snapshots, one per successful
  /// [update]. Does not replay the current value — combine with [current]
  /// or an `initialData:` on [StreamBuilder].
  Stream<Preferences> get stream => _controller.stream;

  /// Latest in-memory [Preferences] snapshot.
  Preferences get current => _current;

  /// Returns the source-specific reader appearance override, if present.
  ReaderAppearanceOverride? readerAppearanceOverrideFor(String sourceId) =>
      _current.readerAppearanceOverrideFor(sourceId);

  /// Returns global reader appearance with the source-specific override applied.
  ReaderAppearancePreferences effectiveReaderAppearanceFor(String sourceId) =>
      _current.effectiveReaderAppearanceFor(sourceId);

  double? readerBrightnessOverrideFor(String sourceId) =>
      _current.readerBrightnessOverrideFor(sourceId);

  double? get readerBrightness => _current.readerBrightness;

  double get readerLastCustomBrightness => _current.readerLastCustomBrightness;

  Future<void> setReaderBrightness(double? brightness) async {
    await update((prefs) {
      final nextBrightness = _normalizeReaderBrightness(brightness);
      return prefs.copyWith(
        readerBrightness: nextBrightness,
        readerLastCustomBrightness:
            nextBrightness ?? prefs.readerLastCustomBrightness,
      );
    });
  }

  Future<void> setReaderAppearanceOverride(
    String sourceId,
    ReaderAppearanceOverride override,
  ) async {
    if (sourceId.isEmpty) return;
    await update((prefs) {
      final overrides = Map<String, ReaderAppearanceOverride>.of(
        prefs.readerAppearanceOverrides,
      );
      if (override.isEmpty) {
        overrides.remove(sourceId);
      } else {
        overrides[sourceId] = override;
      }
      return prefs.copyWith(
        readerAppearanceOverrides: Map.unmodifiable(overrides),
      );
    });
  }

  Future<void> setReaderBrightnessOverride(
    String sourceId,
    double? brightnessOverride,
  ) async {
    if (sourceId.isEmpty) return;
    final currentOverride =
        readerAppearanceOverrideFor(sourceId) ??
        const ReaderAppearanceOverride();
    await setReaderAppearanceOverride(
      sourceId,
      currentOverride.copyWith(brightnessOverride: brightnessOverride),
    );
  }

  Future<void> clearReaderAppearanceOverride(String sourceId) async {
    if (sourceId.isEmpty) return;
    await update((prefs) {
      if (!prefs.readerAppearanceOverrides.containsKey(sourceId)) return prefs;
      final overrides = Map<String, ReaderAppearanceOverride>.of(
        prefs.readerAppearanceOverrides,
      )..remove(sourceId);
      return prefs.copyWith(
        readerAppearanceOverrides: Map.unmodifiable(overrides),
      );
    });
  }

  /// Applies [transform] to the current snapshot, saves the result, and
  /// emits it on [stream]. Persistence failures are logged, not thrown —
  /// the new value still takes effect for this session.
  Future<void> update(Preferences Function(Preferences) transform) async {
    _current = transform(_current);
    try {
      await _repository.save(_current);
    } catch (e, st) {
      // Save failure is non-fatal: in-memory state is updated and emitted
      // so the UI stays consistent for this session. On next launch the old
      // value is restored from disk.
      developer.log(
        'Failed to persist preferences',
        error: e,
        stackTrace: st,
        name: 'PreferencesService',
      );
    }
    _controller.add(_current);
  }

  Future<void> dispose() => _controller.close();
}

double? _normalizeReaderBrightness(double? value) {
  if (value == null) return null;
  return value.clamp(0.05, 1.0).toDouble();
}
