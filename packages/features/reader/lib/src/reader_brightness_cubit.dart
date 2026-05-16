import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:screen_control_service/screen_control_service.dart';

class ReaderBrightnessState extends Equatable {
  const ReaderBrightnessState({required this.brightnessOverride});

  final double? brightnessOverride;

  bool get usesSystemBrightness => brightnessOverride == null;

  double get sliderValue =>
      brightnessOverride ?? ReaderBrightnessCubit.defaultCustomBrightness;

  int get percent => (sliderValue * 100).round();

  @override
  List<Object?> get props => [brightnessOverride];
}

class ReaderBrightnessCubit extends Cubit<ReaderBrightnessState> {
  ReaderBrightnessCubit({
    required PreferencesService preferencesService,
    required ScreenControlService screenControlService,
  }) : _preferencesService = preferencesService,
       _screenControlService = screenControlService,
       super(
         ReaderBrightnessState(
           brightnessOverride:
               preferencesService.current.readerBrightnessOverride,
         ),
       ) {
    _prefsSub = _preferencesService.stream.listen(_onPreferencesChanged);
  }

  static const double minBrightness = 0.05;
  static const double maxBrightness = 1.0;
  static const double defaultCustomBrightness = 0.7;
  static const _commitDebounce = Duration(milliseconds: 200);

  final PreferencesService _preferencesService;
  final ScreenControlService _screenControlService;
  late final StreamSubscription<Preferences> _prefsSub;
  Timer? _commitTimer;
  double? _pendingBrightness;
  bool _active = false;

  void activate() {
    if (_active) return;
    _active = true;
    unawaited(_syncPlatform());
  }

  Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    await _resetPlatform();
  }

  void previewBrightness(double value) {
    final nextValue = _clampBrightness(value);
    if (state.brightnessOverride == nextValue) return;
    emit(ReaderBrightnessState(brightnessOverride: nextValue));
    unawaited(_syncPlatform());
  }

  void commitBrightness(double value) {
    _pendingBrightness = _clampBrightness(value);
    _commitTimer?.cancel();
    _commitTimer = Timer(_commitDebounce, _flushBrightness);
  }

  Future<void> useSystemBrightness() async {
    _pendingBrightness = null;
    _commitTimer?.cancel();
    _commitTimer = null;
    if (!state.usesSystemBrightness) {
      emit(const ReaderBrightnessState(brightnessOverride: null));
    }
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerBrightnessOverride: null),
    );
    await _syncPlatform();
  }

  void _onPreferencesChanged(Preferences prefs) {
    if (isClosed) return;
    if (prefs != _preferencesService.current) return;
    final next = ReaderBrightnessState(
      brightnessOverride: prefs.readerBrightnessOverride,
    );
    if (next == state) return;
    emit(next);
    unawaited(_syncPlatform());
  }

  Future<void> _flushBrightness() async {
    _commitTimer = null;
    final value = _pendingBrightness;
    if (value == null) return;
    _pendingBrightness = null;
    await _preferencesService.update(
      (prefs) => prefs.copyWith(readerBrightnessOverride: value),
    );
  }

  Future<void> _syncPlatform() {
    if (!_active) return Future<void>.value();
    final value = state.brightnessOverride;
    if (value == null) return _resetPlatform();
    return _setPlatformBrightness(value);
  }

  Future<void> _setPlatformBrightness(double value) async {
    try {
      await _screenControlService.setApplicationBrightness(value);
    } catch (e, st) {
      addError(e, st);
    }
  }

  Future<void> _resetPlatform() async {
    try {
      await _screenControlService.resetApplicationBrightness();
    } catch (e, st) {
      addError(e, st);
    }
  }

  static double _clampBrightness(double value) =>
      value.clamp(minBrightness, maxBrightness).toDouble();

  @override
  Future<void> close() async {
    _commitTimer?.cancel();
    await _flushBrightness();
    if (_active) {
      await deactivate();
    }
    await _prefsSub.cancel();
    return super.close();
  }
}
