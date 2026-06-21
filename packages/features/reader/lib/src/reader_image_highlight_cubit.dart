import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:reader_webview/reader_webview.dart';

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
    required HighlightRepository highlightRepository,
  }) : _highlightRepository = highlightRepository,
       super(const ReaderImageHighlightState());

  final HighlightRepository _highlightRepository;

  Future<void> save({
    required String sourceId,
    required SourceType sourceType,
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required HighlightColor color,
    double? progress,
    String? chapterTitle,
  }) async {
    if (state.status == ReaderImageHighlightStatus.saving) return;
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
      );
      if (isClosed) return;
      emit(const ReaderImageHighlightState());
    } catch (error, stackTrace) {
      if (!isClosed) emit(const ReaderImageHighlightState());
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
