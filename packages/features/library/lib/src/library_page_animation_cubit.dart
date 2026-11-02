import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

/// The app-wide page animation selected from Library's display settings.
class LibraryPageAnimationCubit extends Cubit<ReaderPageAnimation> {
  LibraryPageAnimationCubit({required PreferencesService preferencesService})
    : _preferencesService = preferencesService,
      super(preferencesService.current.readerPageAnimation) {
    _subscription = preferencesService.stream.listen(_onPreferencesChanged);
  }

  final PreferencesService _preferencesService;
  late final StreamSubscription<Preferences> _subscription;

  void _onPreferencesChanged(Preferences preferences) {
    // An older queued save must not undo a newer in-memory choice.
    if (isClosed || preferences != _preferencesService.current) return;
    emit(preferences.readerPageAnimation);
  }

  Future<void> setPageAnimation(ReaderPageAnimation animation) async {
    if (isClosed || state == animation) return;
    emit(animation);
    try {
      await _preferencesService.update(
        (preferences) => preferences.copyWith(readerPageAnimation: animation),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(_preferencesService.current.readerPageAnimation);
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
