import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'highlight_state.dart';

class HighlightCubit extends Cubit<HighlightSheetState> {
  HighlightCubit({
    required HighlightRepository highlightRepository,
    required FsrsRepository fsrsRepository,
  }) : _repository = highlightRepository,
       _fsrsRepository = fsrsRepository,
       super(const HighlightSheetState());

  final HighlightRepository _repository;
  final FsrsRepository _fsrsRepository;

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
  }) async {
    emit(state.copyWith(status: HighlightSheetStatus.saving));

    try {
      final highlight = await _repository.addHighlight(
        sourceId: sourceId,
        sourceType: sourceType,
        text: text,
        note: state.note.isEmpty ? null : state.note,
        color: state.selectedColor,
        cfiRange: cfiRange,
        pageNumber: pageNumber,
        scrollOffset: scrollOffset,
      );
      try {
        await _fsrsRepository.createReviewItem(
          itemId: highlight.id,
          itemType: ReviewableType.highlight,
          sourceId: sourceId,
        );
      } catch (e, st) {
        // Non-fatal: highlight is saved; missing FSRS row just means it
        // won't appear in review queue until next manual registration.
        addError(e, st);
      }
      emit(state.copyWith(status: HighlightSheetStatus.success));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: HighlightSheetStatus.failure));
    }
  }
}
