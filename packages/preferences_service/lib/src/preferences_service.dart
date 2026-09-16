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
/// so the current session stays consistent. The next launch reads the last
/// successfully persisted snapshot, which may come from a later update.
class PreferencesService {
  PreferencesService._(this._repository, this._current);

  final PreferencesRepository _repository;
  final _controller = StreamController<Preferences>.broadcast();
  Preferences _current;
  Future<void>? _updateTail;
  int _latestUpdateId = 0;
  Future<void>? _disposeFuture;
  bool _acceptsUpdates = true;

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

  /// Broadcast snapshots in persistence order, including failed save attempts.
  /// Does not replay the current value; use [current] for the initial snapshot.
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

  bool hasAcceptedBookImportTerms(int version) {
    if (version <= 0) return true;
    return _current.bookImportTermsAcceptedVersion >= version;
  }

  Future<void> acceptBookImportTerms(int version) async {
    if (version <= 0 || hasAcceptedBookImportTerms(version)) return;
    await update(
      (prefs) => prefs.copyWith(bookImportTermsAcceptedVersion: version),
    );
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
      final normalizedOverride = override.withoutValuesMatching(
        prefs.readerAppearance,
      );
      if (normalizedOverride.isEmpty) {
        overrides.remove(sourceId);
      } else {
        overrides[sourceId] = normalizedOverride;
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

  /// Applies [transform] to [current] immediately, then queues save and stream
  /// emission in update order. Persistence failures are logged, not thrown;
  /// transform failures and updates after disposal still fail the future.
  Future<void> update(Preferences Function(Preferences) transform) {
    if (!_acceptsUpdates) {
      return Future<void>.error(
        StateError('PreferencesService has been disposed'),
      );
    }

    late final Preferences updated;
    try {
      updated = transform(_current);
    } catch (e, st) {
      return Future<void>.error(e, st);
    }
    _current = updated;

    final previous = _updateTail;
    final updateId = ++_latestUpdateId;

    Future<void> persist() async {
      try {
        await _persistAndEmit(updated);
      } finally {
        if (_latestUpdateId == updateId) {
          _updateTail = null;
        }
      }
    }

    final operation = previous == null
        ? persist()
        : previous.then<void>(
            (_) => persist(),
            onError: (Object _, StackTrace _) => persist(),
          );
    _updateTail = operation;
    return operation;
  }

  Future<void> _persistAndEmit(Preferences snapshot) async {
    try {
      await _repository.save(snapshot);
    } catch (e, st) {
      // Keep the session usable on disk failure. A later successful save may
      // still persist this edit as part of its complete snapshot.
      developer.log(
        'Failed to persist preferences',
        error: e,
        stackTrace: st,
        name: 'PreferencesService',
      );
    }
    _controller.add(snapshot);
  }

  Future<void> dispose() {
    _acceptsUpdates = false;
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    await _updateTail;
    await _controller.close();
  }
}

double? _normalizeReaderBrightness(double? value) {
  if (value == null) return null;
  return value.clamp(0.05, 1.0).toDouble();
}
