import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

part 'profile_translation_state.dart';

/// Drives translation language preferences shown on [ProfileScreen].
///
/// Keeps this slice separate from [ProfileAppearanceCubit] so translation
/// settings do not accidentally rebuild reader appearance controls.
class ProfileTranslationCubit extends Cubit<ProfileTranslationState> {
  ProfileTranslationCubit({
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         ProfileTranslationState.fromPreferences(preferencesService.current),
       ) {
    _prefsSub = _preferencesService.stream.listen(_onPrefs);
  }

  final PreferencesService _preferencesService;
  late final StreamSubscription<Preferences> _prefsSub;

  void _onPrefs(Preferences prefs) {
    if (isClosed) return;
    final currentPrefs = _preferencesService.current;
    // Broadcast delivery can lag behind rapid consecutive writes; ignore
    // stale echoes so the UI does not flicker back to an older selection.
    if (prefs.translationTargetLanguageCode !=
            currentPrefs.translationTargetLanguageCode ||
        prefs.translationSourceLanguageCode !=
            currentPrefs.translationSourceLanguageCode) {
      return;
    }
    final next = ProfileTranslationState.fromPreferences(prefs);
    if (next == state) return;
    emit(next);
  }

  Future<void> setTargetLanguageCode(String code) async {
    final targetCode = Preferences.normalizeTranslationTargetLanguageCode(code);
    if (targetCode == state.targetLanguageCode) return;

    final previous = state;
    emit(
      ProfileTranslationState(
        targetLanguageCode: targetCode,
        sourceLanguageCode: state.sourceLanguageCode,
      ),
    );

    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(
          translationTargetLanguageCode: targetCode,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      emit(previous);
      addError(e, st);
    }
  }

  Future<void> setSourceLanguageCode(String? code) async {
    final sourceCode = Preferences.normalizeTranslationSourceLanguageCode(code);
    if (sourceCode == state.sourceLanguageCode) return;

    final previous = state;
    emit(
      ProfileTranslationState(
        targetLanguageCode: state.targetLanguageCode,
        sourceLanguageCode: sourceCode,
      ),
    );

    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(
          translationSourceLanguageCode: sourceCode,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      emit(previous);
      addError(e, st);
    }
  }

  @override
  Future<void> close() async {
    await _prefsSub.cancel();
    return super.close();
  }
}
