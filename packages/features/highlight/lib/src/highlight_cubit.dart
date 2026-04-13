import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'highlight_state.dart';

class HighlightCubit extends Cubit<HighlightSheetState> {
  HighlightCubit({required HighlightRepository highlightRepository})
    : _repository = highlightRepository,
      super(const HighlightSheetState());

  final HighlightRepository _repository;

  void setColor(HighlightColor color) {
    emit(state.copyWith(selectedColor: color));
  }

  void setNote(String note) {
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
      await _repository.addHighlight(
        sourceId: sourceId,
        sourceType: sourceType,
        text: text,
        note: state.note.isEmpty ? null : state.note,
        color: state.selectedColor,
        cfiRange: cfiRange,
        pageNumber: pageNumber,
        scrollOffset: scrollOffset,
      );
      emit(state.copyWith(status: HighlightSheetStatus.success));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: HighlightSheetStatus.failure));
    }
  }
}
