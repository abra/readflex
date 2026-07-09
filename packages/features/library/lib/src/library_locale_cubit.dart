import 'dart:ui' show Locale;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

class LibraryLocaleCubit extends Cubit<Locale> {
  LibraryLocaleCubit({required PreferencesService preferencesService})
    : _preferencesService = preferencesService,
      super(preferencesService.current.locale);

  final PreferencesService _preferencesService;

  Future<void> setLocale(Locale locale) async {
    if (state == locale) return;
    emit(locale);
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(locale: locale),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}
