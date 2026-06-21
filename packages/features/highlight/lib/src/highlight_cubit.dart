import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'highlight_state.dart';

/// Drives the highlight bottom sheet: holds the draft color and note,
/// and persists the highlight via [HighlightRepository] on save.
class HighlightCubit extends Cubit<HighlightSheetState> {
  HighlightCubit({
    required HighlightRepository highlightRepository,
  }) : _repository = highlightRepository,
       super(const HighlightSheetState());

  final HighlightRepository _repository;

  void setColor(HighlightColor color) {
    if (state.selectedColor == color) return;
    emit(state.copyWith(selectedColor: color));
  }

  void setNote(String note) {
    if (state.note == note) return;
    emit(state.copyWith(note: note));
  }

  Future<void> save({
    required String text,
    required String sourceId,
    required SourceType sourceType,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
    double? progress,
    String? chapterTitle,
    List<String> replaceHighlightIds = const [],
  }) async {
    emit(state.copyWith(status: HighlightSheetStatus.saving));

    try {
      await _repository.addHighlight(
        sourceId: sourceId,
        sourceType: sourceType,
        text: text,
        note: state.note.isEmpty ? null : state.note,
        color: state.selectedColor,
        cfiRange: cfiRange,
        pageNumber: pageNumber,
        scrollOffset: scrollOffset,
        progress: progress,
        chapterTitle: chapterTitle,
        replaceHighlightIds: replaceHighlightIds,
      );
      // Sheet may be dismissed mid-save; the cubit is then closed and
      // emit would throw StateError. Bail instead — the highlight
      // itself is already persisted.
      if (isClosed) return;
      emit(state.copyWith(status: HighlightSheetStatus.success));
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(state.copyWith(status: HighlightSheetStatus.failure));
    }
  }
}
