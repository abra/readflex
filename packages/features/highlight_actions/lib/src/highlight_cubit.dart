import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:domain_models/domain_models.dart';

enum HighlightSheetStatus { idle, saving, success, failure }

final class HighlightSheetState extends Equatable {
  const HighlightSheetState({
    this.status = HighlightSheetStatus.idle,
    this.selectedColor = HighlightColor.yellow,
    this.note = '',
  });

  final HighlightSheetStatus status;
  final HighlightColor selectedColor;
  final String note;

  HighlightSheetState copyWith({
    HighlightSheetStatus? status,
    HighlightColor? selectedColor,
    String? note,
  }) => HighlightSheetState(
    status: status ?? this.status,
    selectedColor: selectedColor ?? this.selectedColor,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => [status, selectedColor, note];
}

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
    } catch (e) {
      emit(state.copyWith(status: HighlightSheetStatus.failure));
    }
  }
}
