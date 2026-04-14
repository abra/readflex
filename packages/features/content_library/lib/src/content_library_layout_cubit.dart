import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

part 'content_library_layout_state.dart';

class ContentLibraryLayoutCubit extends Cubit<ContentLibraryLayoutMode> {
  ContentLibraryLayoutCubit({
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         ContentLibraryLayoutModeX.fromId(
           preferencesService.current.contentLibraryLayoutMode,
         ),
       );

  final PreferencesService _preferencesService;

  Future<void> setLayoutMode(ContentLibraryLayoutMode mode) async {
    if (state == mode) return;
    emit(mode);
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(contentLibraryLayoutMode: mode.id),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}
