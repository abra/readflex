import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

import 'practice_settings_presets.dart';

part 'practice_settings_state.dart';

/// The Practice settings sheet's state: the three preferences a session
/// reads, as the sheet's choices. A change shows at once and is written to
/// [PreferencesService]; a failed write is reported and the choice goes
/// back, so the sheet never shows a setting that was not kept.
class PracticeSettingsCubit extends Cubit<PracticeSettingsState> {
  PracticeSettingsCubit({required PreferencesService preferencesService})
    : _preferencesService = preferencesService,
      super(PracticeSettingsState.of(preferencesService.current));

  final PreferencesService _preferencesService;

  Future<void> setNewCardsPerDay(int newCardsPerDay) => _change(
    state.copyWith(newCardsPerDay: newCardsPerDay),
    (prefs) => prefs.copyWith(practiceNewCardsPerDay: newCardsPerDay),
  );

  Future<void> setReviewHighlights(bool reviewHighlights) => _change(
    state.copyWith(reviewHighlights: reviewHighlights),
    (prefs) => prefs.copyWith(practiceReviewHighlights: reviewHighlights),
  );

  Future<void> setMemoryTarget(PracticeMemoryTarget memoryTarget) => _change(
    state.copyWith(memoryTarget: memoryTarget),
    (prefs) => prefs.copyWith(
      practiceDesiredRetention: memoryTarget.desiredRetention,
    ),
  );

  Future<void> _change(
    PracticeSettingsState next,
    Preferences Function(Preferences prefs) write,
  ) async {
    if (next == state) return;
    final previous = state;
    emit(next);
    try {
      await _preferencesService.update(write);
    } catch (e, st) {
      addError(e, st);
      if (!isClosed) emit(previous);
    }
  }
}
