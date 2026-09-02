import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_control_service/screen_control_service.dart';

/// Keeps the device screen awake only while the reader is actively showing
/// content in the foreground, and releases that request for controls,
/// background lifecycle states, and disposal.
class ReaderKeepAwakeCubit extends Cubit<bool> {
  ReaderKeepAwakeCubit({
    required ScreenControlService screenControlService,
  }) : _screenControlService = screenControlService,
       super(false);

  final ScreenControlService _screenControlService;
  bool _foreground = true;
  bool _platformKeepAwake = false;
  bool _closing = false;
  Future<void> _syncTail = Future<void>.value();

  void setActive(bool active) {
    if (_closing || isClosed) return;
    if (state == active) return;
    emit(active);
    _scheduleSync();
  }

  void appLifecycleChanged(AppLifecycleState state) {
    if (_closing || isClosed) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _scheduleSync();
  }

  void _scheduleSync() {
    _syncTail = _syncTail.then((_) => _applyDesiredState()).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (!isClosed) addError(error, stackTrace);
    });
  }

  Future<void> _applyDesiredState() async {
    final shouldKeepAwake = !_closing && state && _foreground;
    if (shouldKeepAwake == _platformKeepAwake) return;

    if (shouldKeepAwake) {
      await _screenControlService.keepAwake();
    } else {
      await _screenControlService.allowSleep();
    }
    _platformKeepAwake = shouldKeepAwake;
  }

  @override
  Future<void> close() async {
    _closing = true;
    _scheduleSync();
    await _syncTail;
    return super.close();
  }
}
