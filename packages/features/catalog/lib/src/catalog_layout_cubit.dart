import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

part 'catalog_layout_state.dart';

class CatalogLayoutCubit extends Cubit<CatalogLayoutMode> {
  CatalogLayoutCubit({
    required PreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         CatalogLayoutModeX.fromId(
           preferencesService.current.catalogLayoutMode,
         ),
       );

  final PreferencesService _preferencesService;

  Future<void> setLayoutMode(CatalogLayoutMode mode) async {
    if (state == mode) return;
    emit(mode);
    try {
      await _preferencesService.update(
        (prefs) => prefs.copyWith(catalogLayoutMode: mode.id),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}
