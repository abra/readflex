import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

enum ContentLibraryLayoutMode { list, grid }

extension ContentLibraryLayoutModeX on ContentLibraryLayoutMode {
  String get id => name;

  static ContentLibraryLayoutMode fromId(String? value) => switch (value) {
    'list' => ContentLibraryLayoutMode.list,
    _ => ContentLibraryLayoutMode.grid,
  };
}

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
    await _preferencesService.update(
      (prefs) => prefs.copyWith(contentLibraryLayoutMode: mode.id),
    );
  }
}
