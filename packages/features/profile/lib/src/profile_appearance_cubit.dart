import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

final class ProfileAppearanceState {
  const ProfileAppearanceState({
    required this.themeMode,
    required this.readerAppearance,
  });

  final ThemeMode themeMode;
  final ReaderAppearancePreferences readerAppearance;

  ProfileAppearanceState copyWith({
    ThemeMode? themeMode,
    ReaderAppearancePreferences? readerAppearance,
  }) => ProfileAppearanceState(
    themeMode: themeMode ?? this.themeMode,
    readerAppearance: readerAppearance ?? this.readerAppearance,
  );
}

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
    emit(state.copyWith(themeMode: themeMode));
    await _preferencesService.update(
      (prefs) => prefs.copyWith(themeMode: themeMode),
    );
  }

  Future<void> setReaderTheme(String themeId) async {
    final appearance = state.readerAppearance;
    emit(
      state.copyWith(
        readerAppearance: ReaderAppearancePreferences(
          themeId: themeId,
          fontId: appearance.fontId,
          textScale: appearance.textScale,
          lineHeight: appearance.lineHeight,
        ),
      ),
    );
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerThemeId: themeId),
    );
  }

  Future<void> setReaderFont(String fontId) async {
    final appearance = state.readerAppearance;
    emit(
      state.copyWith(
        readerAppearance: ReaderAppearancePreferences(
          themeId: appearance.themeId,
          fontId: fontId,
          textScale: appearance.textScale,
          lineHeight: appearance.lineHeight,
        ),
      ),
    );
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerFontId: fontId),
    );
  }

  void previewTextScale(double value) {
    final appearance = state.readerAppearance;
    emit(
      state.copyWith(
        readerAppearance: ReaderAppearancePreferences(
          themeId: appearance.themeId,
          fontId: appearance.fontId,
          textScale: value,
          lineHeight: appearance.lineHeight,
        ),
      ),
    );
  }

  Future<void> commitTextScale(double value) async {
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerTextScale: value),
    );
  }

  void previewLineHeight(double value) {
    final appearance = state.readerAppearance;
    emit(
      state.copyWith(
        readerAppearance: ReaderAppearancePreferences(
          themeId: appearance.themeId,
          fontId: appearance.fontId,
          textScale: appearance.textScale,
          lineHeight: value,
        ),
      ),
    );
  }

  Future<void> commitLineHeight(double value) async {
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerLineHeight: value),
    );
  }
}
