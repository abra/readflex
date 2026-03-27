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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileAppearanceState &&
          themeMode == other.themeMode &&
          readerAppearance == other.readerAppearance;

  @override
  int get hashCode => Object.hash(themeMode, readerAppearance);
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
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(themeId: themeId),
      ),
    );
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerThemeId: themeId),
    );
  }

  Future<void> setReaderFont(String fontId) async {
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(fontId: fontId),
      ),
    );
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerFontId: fontId),
    );
  }

  void previewTextScale(double value) {
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(textScale: value),
      ),
    );
  }

  Future<void> commitTextScale(double value) async {
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerTextScale: value),
    );
  }

  void previewLineHeight(double value) {
    emit(
      state.copyWith(
        readerAppearance: state.readerAppearance.copyWith(lineHeight: value),
      ),
    );
  }

  Future<void> commitLineHeight(double value) async {
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerLineHeight: value),
    );
  }
}
