import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

const _kClearProtectionDuration = Duration(milliseconds: 700);

/// Current image-page area selection mirrored from the WebView.
class ReaderImageSelectionState extends Equatable {
  const ReaderImageSelectionState({
    this.pageIndex,
    this.rect,
    this.position,
    this.progress,
    this.chapterTitle,
    this.hasSelection = false,
  });

  final int? pageIndex;
  final ReaderImageAreaRect? rect;
  final ReaderSelectionPosition? position;
  final double? progress;
  final String? chapterTitle;
  final bool hasSelection;

  @override
  List<Object?> get props => [
    pageIndex,
    rect,
    position,
    progress,
    chapterTitle,
    hasSelection,
  ];
}

class ReaderImageSelectionCubit extends Cubit<ReaderImageSelectionState> {
  ReaderImageSelectionCubit() : super(const ReaderImageSelectionState());

  Timer? _clearProtectionTimer;
  bool _protectNextClear = false;
  bool _holdClearProtection = false;

  void select({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    ReaderSelectionPosition? position,
    double? progress,
    String? chapterTitle,
  }) {
    emit(
      ReaderImageSelectionState(
        pageIndex: pageIndex,
        rect: rect,
        position: position,
        progress: progress,
        chapterTitle: chapterTitle,
        hasSelection: true,
      ),
    );
  }

  void protectNextClear() {
    if (_holdClearProtection) return;
    _protectNextClear = true;
    _clearProtectionTimer?.cancel();
    _clearProtectionTimer = Timer(_kClearProtectionDuration, () {
      _protectNextClear = false;
      _clearProtectionTimer = null;
    });
  }

  void holdClearProtection() {
    _holdClearProtection = true;
    _protectNextClear = false;
    _clearProtectionTimer?.cancel();
    _clearProtectionTimer = null;
  }

  void releaseClearProtection() {
    _holdClearProtection = false;
    _protectNextClear = false;
    _clearProtectionTimer?.cancel();
    _clearProtectionTimer = null;
  }

  bool consumeProtectedClear() {
    if (_holdClearProtection) return true;
    if (!_protectNextClear) return false;
    _protectNextClear = false;
    _clearProtectionTimer?.cancel();
    _clearProtectionTimer = null;
    return true;
  }

  void deselect() {
    releaseClearProtection();
    emit(const ReaderImageSelectionState());
  }

  @override
  Future<void> close() {
    _clearProtectionTimer?.cancel();
    _holdClearProtection = false;
    return super.close();
  }
}
