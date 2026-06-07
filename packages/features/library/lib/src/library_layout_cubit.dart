import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

part 'library_layout_state.dart';

class LibraryLayoutCubit extends Cubit<LibraryLayoutMode> {
  LibraryLayoutCubit({
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         LibraryLayoutModeX.fromId(
           preferencesService.current.libraryLayoutMode,
         ),
       );

  final PreferencesService _preferencesService;

  Future<void> setLayoutMode(LibraryLayoutMode mode) async {
    if (state == mode) return;
    emit(mode);
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(libraryLayoutMode: mode.id),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}
