part of 'reader_bloc.dart';

extension _ReaderHighlightOperations on ReaderBloc {
  /// Restores the deleted rows, including the original review schedule.
  Future<void> _restoreHighlight(
    String highlightId,
    String sourceId,
    Emitter<ReaderState> emit,
  ) async {
    final removed = state.highlightEdits.removed;
    final deletion = _highlightDeletions[highlightId];
    if (deletion == null ||
        deletion.highlight.sourceId != sourceId ||
        !removed.any((highlight) => highlight.id == highlightId)) {
      return;
    }
    bool isCurrent() => !emit.isDone && state.sourceId == sourceId;
    emit(
      state.copyWith(
        highlightEdits: ReaderHighlightEdits(
          removed: removed,
          busyId: highlightId,
        ),
      ),
    );
    try {
      await _highlightRepository.restoreHighlight(deletion);
      final highlights = await _highlightRepository.getHighlightsBySource(
        sourceId,
      );
      if (!isCurrent()) return;
      _highlightDeletions.remove(highlightId);
      _highlightRevision++;
      emit(
        state.copyWith(
          highlights: highlights,
          highlightEdits: ReaderHighlightEdits(
            removed: [
              for (final h in removed)
                if (h.id != highlightId) h,
            ],
          ),
        ),
      );
    } catch (error, stack) {
      reportError(error, stack);
      if (!isCurrent()) return;
      emit(
        state.copyWith(
          highlightEdits: ReaderHighlightEdits(
            removed: removed,
            failedId: highlightId,
          ),
        ),
      );
    }
  }
}
