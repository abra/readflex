import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reader_selection.dart';

/// Current image-page area selection mirrored from the page.
class ReaderImageSelectionState extends Equatable {
  const ReaderImageSelectionState({
    this.pageIndex,
    this.rect,
    this.position,
    this.progress,
    this.chapterTitle,
    this.hasSelection = false,
    this.isAdjusting = false,
    this.selectionId = 0,
  });

  final int? pageIndex;
  final ReaderImageAreaRect? rect;
  final ReaderSelectionPosition? position;
  final double? progress;
  final String? chapterTitle;
  final bool hasSelection;

  /// The engine is moving/resizing the draft; popup actions wait for commit.
  final bool isAdjusting;

  /// One draft's identity across commits; zero when there is no selection.
  final int selectionId;

  @override
  List<Object?> get props => [
    pageIndex,
    rect,
    position,
    progress,
    chapterTitle,
    hasSelection,
    isAdjusting,
    selectionId,
  ];
}

class ReaderImageSelectionCubit extends Cubit<ReaderImageSelectionState> {
  ReaderImageSelectionCubit() : super(const ReaderImageSelectionState());

  int _lastSelectionId = 0;

  void select({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    ReaderSelectionPosition? position,
    double? progress,
    String? chapterTitle,
  }) {
    if (isClosed) return;
    emit(
      ReaderImageSelectionState(
        pageIndex: pageIndex,
        rect: rect,
        position: position,
        progress: progress,
        chapterTitle: chapterTitle,
        hasSelection: true,
        isAdjusting: state.isAdjusting,
        selectionId: state.hasSelection
            ? state.selectionId
            : ++_lastSelectionId,
      ),
    );
  }

  /// Only gesture boundaries cross the engine/app boundary, not each pixel.
  void setAdjustment(bool value) {
    if (isClosed || state.isAdjusting == value) return;
    emit(
      ReaderImageSelectionState(
        pageIndex: state.pageIndex,
        rect: state.rect,
        position: state.position,
        progress: state.progress,
        chapterTitle: state.chapterTitle,
        hasSelection: state.hasSelection,
        isAdjusting: value,
        selectionId: state.selectionId,
      ),
    );
  }

  void deselect() {
    if (isClosed) return;
    emit(const ReaderImageSelectionState());
  }
}
