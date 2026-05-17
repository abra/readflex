import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

class ReaderAppearanceState extends Equatable {
  const ReaderAppearanceState({
    required this.globalAppearance,
    required this.sourceOverride,
    required this.effectiveAppearance,
  });

  factory ReaderAppearanceState.fromPreferences({
    required Preferences preferences,
    required String sourceId,
  }) {
    final override =
        preferences.readerAppearanceOverrideFor(sourceId) ??
        const ReaderAppearanceOverride();
    return ReaderAppearanceState(
      globalAppearance: preferences.readerAppearance,
      sourceOverride: override,
      effectiveAppearance: override.applyTo(preferences.readerAppearance),
    );
  }

  final ReaderAppearancePreferences globalAppearance;
  final ReaderAppearanceOverride sourceOverride;
  final ReaderAppearancePreferences effectiveAppearance;

  bool get hasOverride => !sourceOverride.isEmpty;

  bool get isFactoryDefault =>
      effectiveAppearance == ReaderAppearancePreferences.defaults;

  @override
  List<Object?> get props => [
    globalAppearance,
    sourceOverride,
    effectiveAppearance,
  ];
}

/// Reader-local appearance controller.
///
/// Profile owns the global reader defaults. This cubit stores only the fields
/// changed for the current source, so future global changes still flow through
/// unless a book-specific override exists for that exact trait.
class ReaderAppearanceCubit extends Cubit<ReaderAppearanceState> {
  ReaderAppearanceCubit({
    required PreferencesService preferencesService,
    required String sourceId,
  }) : _preferencesService = preferencesService,
       _sourceId = sourceId,
       super(
         ReaderAppearanceState.fromPreferences(
           preferences: preferencesService.current,
           sourceId: sourceId,
         ),
       ) {
    _prefsSub = _preferencesService.stream.listen(_onPreferencesChanged);
  }

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.45;
  static const double textScaleStep = 0.05;
  static const List<double> lineHeightPresets = [1.2, 1.4, 1.6, 1.8, 2.0];
  static const double lineHeightMatchTolerance = 0.05;
  static const double minSideMargin = 2;
  static const double maxSideMargin = 14;
  static const double sideMarginStep = 1;

  static const _commitDebounce = Duration(milliseconds: 200);

  final PreferencesService _preferencesService;
  final String _sourceId;
  late final StreamSubscription<Preferences> _prefsSub;
  Timer? _textScaleCommitTimer;
  double? _pendingTextScale;
  Timer? _lineHeightCommitTimer;
  double? _pendingLineHeight;
  Timer? _sideMarginCommitTimer;
  double? _pendingSideMargin;

  void _onPreferencesChanged(Preferences prefs) {
    if (isClosed) return;
    if (prefs != _preferencesService.current) return;
    final next = ReaderAppearanceState.fromPreferences(
      preferences: prefs,
      sourceId: _sourceId,
    );
    if (next == state) return;
    emit(next);
  }

  Future<void> setTheme(String themeId) async {
    final next = state.sourceOverride.copyWith(
      themeId: themeId == state.globalAppearance.themeId ? null : themeId,
    );
    await _persistOverride(next);
  }

  Future<void> setFont(String fontId) async {
    final next = state.sourceOverride.copyWith(
      fontId: fontId == state.globalAppearance.fontId ? null : fontId,
    );
    await _persistOverride(next);
  }

  Future<void> setTextAlignment(ReaderTextAlignment alignment) async {
    final next = state.sourceOverride.copyWith(
      textAlignment: alignment == state.globalAppearance.textAlignment
          ? null
          : alignment,
    );
    await _persistOverride(next);
  }

  void previewTextScale(double value) {
    final nextValue = value.clamp(minTextScale, maxTextScale).toDouble();
    final next = state.sourceOverride.copyWith(
      textScale: nextValue == state.globalAppearance.textScale
          ? null
          : nextValue,
    );
    _emitOverride(next);
  }

  void commitTextScale(double value) {
    _pendingTextScale = value.clamp(minTextScale, maxTextScale).toDouble();
    _textScaleCommitTimer?.cancel();
    _textScaleCommitTimer = Timer(_commitDebounce, _flushTextScale);
  }

  Future<void> resetTextScale() async {
    _pendingTextScale = null;
    _textScaleCommitTimer?.cancel();
    _textScaleCommitTimer = null;
    final defaultTextScale = ReaderAppearancePreferences.defaults.textScale;
    final next = state.sourceOverride.copyWith(
      textScale: state.globalAppearance.textScale == defaultTextScale
          ? null
          : defaultTextScale,
    );
    await _persistOverride(next);
  }

  void previewLineHeight(double value) {
    final next = state.sourceOverride.copyWith(
      lineHeight: value == state.globalAppearance.lineHeight ? null : value,
    );
    _emitOverride(next);
  }

  void commitLineHeight(double value) {
    _pendingLineHeight = value;
    _lineHeightCommitTimer?.cancel();
    _lineHeightCommitTimer = Timer(_commitDebounce, _flushLineHeight);
  }

  void previewSideMargin(double value) {
    final nextValue = value.clamp(minSideMargin, maxSideMargin).toDouble();
    final next = state.sourceOverride.copyWith(
      sideMargin: nextValue == state.globalAppearance.sideMargin
          ? null
          : nextValue,
    );
    _emitOverride(next);
  }

  void commitSideMargin(double value) {
    _pendingSideMargin = value.clamp(minSideMargin, maxSideMargin).toDouble();
    _sideMarginCommitTimer?.cancel();
    _sideMarginCommitTimer = Timer(_commitDebounce, _flushSideMargin);
  }

  Future<void> reset() async {
    _textScaleCommitTimer?.cancel();
    _lineHeightCommitTimer?.cancel();
    _sideMarginCommitTimer?.cancel();
    _textScaleCommitTimer = null;
    _lineHeightCommitTimer = null;
    _sideMarginCommitTimer = null;
    _pendingTextScale = null;
    _pendingLineHeight = null;
    _pendingSideMargin = null;
    await _persistOverride(const ReaderAppearanceOverride());
  }

  Future<void> _flushTextScale() async {
    _textScaleCommitTimer = null;
    final value = _pendingTextScale;
    if (value == null) return;
    _pendingTextScale = null;
    final next = state.sourceOverride.copyWith(
      textScale: value == state.globalAppearance.textScale ? null : value,
    );
    await _persistOverride(next, emitOptimistic: false);
  }

  Future<void> _flushSideMargin() async {
    _sideMarginCommitTimer = null;
    final value = _pendingSideMargin;
    if (value == null) return;
    _pendingSideMargin = null;
    final next = state.sourceOverride.copyWith(
      sideMargin: value == state.globalAppearance.sideMargin ? null : value,
    );
    await _persistOverride(next, emitOptimistic: false);
  }

  Future<void> _flushLineHeight() async {
    _lineHeightCommitTimer = null;
    final value = _pendingLineHeight;
    if (value == null) return;
    _pendingLineHeight = null;
    final next = state.sourceOverride.copyWith(
      lineHeight: value == state.globalAppearance.lineHeight ? null : value,
    );
    await _persistOverride(next, emitOptimistic: false);
  }

  void _emitOverride(ReaderAppearanceOverride override) {
    final next = ReaderAppearanceState(
      globalAppearance: state.globalAppearance,
      sourceOverride: override,
      effectiveAppearance: override.applyTo(state.globalAppearance),
    );
    if (next == state) return;
    emit(next);
  }

  Future<void> _persistOverride(
    ReaderAppearanceOverride override, {
    bool emitOptimistic = true,
  }) async {
    final previous = state;
    if (emitOptimistic) _emitOverride(override);
    try {
      await _preferencesService.setReaderAppearanceOverride(
        _sourceId,
        override,
      );
    } catch (e, st) {
      if (isClosed) return;
      emit(previous);
      addError(e, st);
    }
  }

  @override
  Future<void> close() async {
    _textScaleCommitTimer?.cancel();
    _lineHeightCommitTimer?.cancel();
    _sideMarginCommitTimer?.cancel();
    await _flushTextScale();
    await _flushLineHeight();
    await _flushSideMargin();
    await _prefsSub.cancel();
    return super.close();
  }
}
