import 'dart:async';

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
///
/// Also subscribes to [PreferencesService.stream] so the cubit reflects
/// changes made elsewhere — most notably the reader's font / theme
/// pickers. Without that subscription the cubit kept the snapshot it
/// took in its constructor and the Profile screen drifted out of sync
/// with what the reader was showing.
class ProfileAppearanceCubit extends Cubit<ProfileAppearanceState> {
  ProfileAppearanceCubit({
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         ProfileAppearanceState(
           themeMode: preferencesService.current.themeMode,
           readerAppearance: preferencesService.current.readerAppearance,
         ),
       ) {
    // Pull future updates from anywhere through the broadcast stream —
    // not just our own setters. The Equatable check inside `_onPrefs`
    // makes our own optimistic emit a no-op when the stream echoes
    // back what we just wrote, so we don't double-emit.
    _prefsSub = _preferencesService.stream.listen(_onPrefs);
  }

  final PreferencesService _preferencesService;
  late final StreamSubscription<Preferences> _prefsSub;

  void _onPrefs(Preferences prefs) {
    if (isClosed) return;
    final next = ProfileAppearanceState(
      themeMode: prefs.themeMode,
      readerAppearance: prefs.readerAppearance,
    );
    if (next == state) return;
    emit(next);
  }

  @override
  Future<void> close() {
    _prefsSub.cancel();
    return super.close();
  }

  // All async setters guard the post-await branches with `isClosed`.
  // The Profile screen can be popped (or its scope torn down by a
  // route change) while a `_preferencesService.update` is in flight;
  // without the guard the catch branch's `emit(previous)` and
  // `addError` would throw "Cannot emit/addError after calling close"
  // and crash the bloc framework. Same recipe as ImportFlowCubit /
  // TranslateCubit.
  Future<void> setThemeMode(ThemeMode themeMode) async {
    final previous = state;
    emit(state.copyWith(themeMode: themeMode));
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(themeMode: themeMode),
      );
    } catch (e, st) {
      if (isClosed) return;
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
      if (isClosed) return;
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
      if (isClosed) return;
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
      if (isClosed) return;
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
      if (isClosed) return;
      addError(e, st);
    }
  }
}
