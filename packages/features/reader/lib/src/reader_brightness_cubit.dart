import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:screen_control_service/screen_control_service.dart';

class ReaderBrightnessState extends Equatable {
  const ReaderBrightnessState({
    required this.brightnessOverride,
    this.systemBrightness,
  });

  final double? brightnessOverride;
  final double? systemBrightness;

  bool get usesSystemBrightness => brightnessOverride == null;

  double get sliderValue =>
      brightnessOverride ??
      systemBrightness ??
      ReaderBrightnessCubit.defaultCustomBrightness;

  int get percent => (sliderValue * 100).round();

  @override
  List<Object?> get props => [brightnessOverride, systemBrightness];
}

class ReaderBrightnessCubit extends Cubit<ReaderBrightnessState> {
  ReaderBrightnessCubit({
    required PreferencesService preferencesService,
    required ScreenControlService screenControlService,
    required String sourceId,
  }) : _preferencesService = preferencesService,
       _screenControlService = screenControlService,
       _sourceId = sourceId,
       super(
         ReaderBrightnessState(
           brightnessOverride: preferencesService.readerBrightnessOverrideFor(
             sourceId,
           ),
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
  final String _sourceId;
  late final StreamSubscription<Preferences> _prefsSub;
  Timer? _commitTimer;
  double? _pendingBrightness;
  bool _active = false;

  void activate() {
    if (_active) return;
    _active = true;
    unawaited(_activate());
  }

  Future<void> _activate() async {
    if (state.usesSystemBrightness) {
      await _resetPlatform();
      await _readPlatformBrightness();
      return;
    }
    await _readPlatformBrightness();
    await _syncPlatform();
  }

  Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    await _resetPlatform();
  }

  void previewBrightness(double value) {
    final nextValue = _clampBrightness(value);
    if (state.brightnessOverride == nextValue) return;
    emit(
      ReaderBrightnessState(
        brightnessOverride: nextValue,
        systemBrightness: state.systemBrightness,
      ),
    );
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
    final currentSystemBrightness = state.systemBrightness;
    if (!state.usesSystemBrightness) {
      emit(
        ReaderBrightnessState(
          brightnessOverride: null,
          systemBrightness: currentSystemBrightness,
        ),
      );
    }
    await _preferencesService.setReaderBrightnessOverride(_sourceId, null);
    await _resetPlatform();
    if (currentSystemBrightness == null) {
      await _readPlatformBrightness();
    }
  }

  void _onPreferencesChanged(Preferences prefs) {
    if (isClosed) return;
    if (prefs != _preferencesService.current) return;
    final next = ReaderBrightnessState(
      brightnessOverride: prefs.readerBrightnessOverrideFor(_sourceId),
      systemBrightness: state.systemBrightness,
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
    await _preferencesService.setReaderBrightnessOverride(_sourceId, value);
  }

  Future<void> _syncPlatform() {
    if (!_active) return Future<void>.value();
    final value = state.brightnessOverride;
    if (value == null) return _resetPlatform();
    return _setPlatformBrightness(value);
  }

  Future<void> _readPlatformBrightness() async {
    if (!_active || isClosed) return;
    try {
      final brightness = await _screenControlService
          .readApplicationBrightness();
      if (brightness == null || isClosed) return;
      final next = ReaderBrightnessState(
        brightnessOverride: state.brightnessOverride,
        systemBrightness: _clampBrightness(brightness),
      );
      if (next == state) return;
      emit(next);
    } catch (e, st) {
      addError(e, st);
    }
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
