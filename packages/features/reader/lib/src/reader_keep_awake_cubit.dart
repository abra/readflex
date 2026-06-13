import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_control_service/screen_control_service.dart';

/// Coordinates reader keep-awake requests with app lifecycle state.
class ReaderKeepAwakeCubit extends Cubit<bool> {
  ReaderKeepAwakeCubit({
    required ScreenControlService screenControlService,
  }) : _screenControlService = screenControlService,
       super(false);

  final ScreenControlService _screenControlService;
  bool _foreground = true;
  bool _keepAwakeRequested = false;

  void setActive(bool active) {
    if (state == active) return;
    emit(active);
    unawaited(_sync());
  }

  void appLifecycleChanged(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      if (state && _foreground) {
        await _keepAwake();
        return;
      }
      await _allowSleep();
    } catch (e, st) {
      if (!isClosed) addError(e, st);
    }
  }

  Future<void> _keepAwake() async {
    if (_keepAwakeRequested) return;
    _keepAwakeRequested = true;
    await _screenControlService.keepAwake();
  }

  Future<void> _allowSleep() async {
    if (!_keepAwakeRequested) return;
    _keepAwakeRequested = false;
    await _screenControlService.allowSleep();
  }

  @override
  Future<void> close() async {
    try {
      await _allowSleep();
    } catch (e, st) {
      if (!isClosed) addError(e, st);
    }
    return super.close();
  }
}
