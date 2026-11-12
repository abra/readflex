import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'reader_selection.dart';

enum ReaderImageHighlightStatus { idle, saving }

class ReaderImageHighlightState extends Equatable {
  const ReaderImageHighlightState({
    this.status = ReaderImageHighlightStatus.idle,
  });

  final ReaderImageHighlightStatus status;

  @override
  List<Object?> get props => [status];
}

/// Saves image-page highlights while ReaderBloc owns highlight list refreshes.
class ReaderImageHighlightCubit extends Cubit<ReaderImageHighlightState> {
  ReaderImageHighlightCubit({
    required this._highlightRepository,
  }) : super(const ReaderImageHighlightState());

  final HighlightRepository _highlightRepository;

  /// Returns false when no write is accepted; true confirms repository success.
  Future<bool> save({
    required String sourceId,
    required SourceType sourceType,
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required HighlightColor color,
    String? note,
    double? progress,
    String? chapterTitle,
  }) async {
    // A closed/busy cubit must not report an unperformed save as successful.
    if (isClosed || state.status == ReaderImageHighlightStatus.saving) {
      return false;
    }
    emit(
      const ReaderImageHighlightState(
        status: ReaderImageHighlightStatus.saving,
      ),
    );
    try {
      await _highlightRepository.addImageAreaHighlight(
        sourceId: sourceId,
        sourceType: sourceType,
        pageIndex: pageIndex,
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: rect.height,
        progress: progress,
        chapterTitle: chapterTitle,
        color: color,
        note: _normalizedNote(note),
      );
      if (!isClosed) emit(const ReaderImageHighlightState());
      return true;
    } catch (error, stackTrace) {
      if (!isClosed) emit(const ReaderImageHighlightState());
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

String? _normalizedNote(String? note) {
  final normalized = note?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}
