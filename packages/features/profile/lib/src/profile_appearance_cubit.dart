import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

part 'profile_appearance_state.dart';

/// Drives the appearance controls on [ProfileScreen] (theme mode, reader
/// theme/font/text scale/line height).
///
/// Writes through [PreferencesService] and rolls state back on failure.
/// Slider "preview" setters (`previewTextScale`, `previewLineHeight`) emit
/// locally for immediate feedback; `commit*` variants persist on drag end.
class ProfileAppearanceCubit extends Cubit<ProfileAppearanceState> {
  ProfileAppearanceCubit({
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         ProfileAppearanceState(
           themeMode: preferencesService.current.themeMode,
           readerAppearance: preferencesService.current.readerAppearance,
         ),
       );

  final PreferencesService _preferencesService;

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final previous = state;
    emit(state.copyWith(themeMode: themeMode));
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(themeMode: themeMode),
      );
    } catch (e, st) {
      emit(previous);
      addError(e, st);
    }
  }

  Future<void> setReaderTheme(String themeId) async {
    final previous = state;
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(themeId: themeId),
      ),
    );
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(readerThemeId: themeId),
      );
    } catch (e, st) {
      emit(previous);
      addError(e, st);
    }
  }

  Future<void> setReaderFont(String fontId) async {
    final previous = state;
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(fontId: fontId),
      ),
    );
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(readerFontId: fontId),
      );
    } catch (e, st) {
      emit(previous);
      addError(e, st);
    }
  }

  void previewTextScale(double value) {
    if (state.readerAppearance.textScale == value) return;
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(textScale: value),
      ),
    );
  }

  Future<void> commitTextScale(double value) async {
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(readerTextScale: value),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }

  void previewLineHeight(double value) {
    if (state.readerAppearance.lineHeight == value) return;
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(lineHeight: value),
      ),
    );
  }

  Future<void> commitLineHeight(double value) async {
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(readerLineHeight: value),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}
