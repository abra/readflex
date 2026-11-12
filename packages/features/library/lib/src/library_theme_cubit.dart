import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

class LibraryThemeCubit extends Cubit<AppThemeMode> {
  LibraryThemeCubit({required PreferencesService preferencesService})
    : _preferencesService = preferencesService,
      super(preferencesService.current.themeMode);

  final PreferencesService _preferencesService;

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (state == mode) return;
    emit(mode);
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(themeMode: mode),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}
