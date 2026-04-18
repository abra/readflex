import 'dart:async' show StreamController;
import 'dart:developer' as developer;

import 'preferences.dart';
import 'preferences_repository.dart';
import 'preferences_storage.dart';

/// Loads, persists and streams [Preferences].
class PreferencesService {
  PreferencesService._(this._repository, this._current);

  final PreferencesRepository _repository;
  final _controller = StreamController<Preferences>.broadcast();
  Preferences _current;

  static Future<PreferencesService> create({
    required List<String> supportedCodes,
  }) async {
    final repository = PreferencesRepository(PreferencesStorage());
    final current = await repository.load(supportedCodes);
    return PreferencesService._(repository, current);
  }

  Stream<Preferences> get stream => _controller.stream;

  Preferences get current => _current;

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
}
