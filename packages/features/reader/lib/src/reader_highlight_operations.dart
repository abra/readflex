part of 'reader_bloc.dart';

extension _ReaderHighlightOperations on ReaderBloc {
  /// Re-adds a highlight removed from the open Contents session. There is no
  /// restore API, so the row is inserted again with a new id while keeping its
  /// original date so it returns to the same list position.
  Future<void> _restoreHighlight(
    String highlightId,
    String sourceId,
    Emitter<ReaderState> emit,
  ) async {
    final removed = state.highlightEdits.removed;
    final highlight = removed.where((h) => h.id == highlightId).firstOrNull;
    if (highlight == null) return;
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
      final added = await _addHighlightAgain(highlight);
      if (added.createdAt != highlight.createdAt) {
        await _highlightRepository.updateHighlight(
          _withCreatedAt(added, highlight.createdAt),
        );
      }
      final highlights = await _highlightRepository.getHighlightsBySource(
        sourceId,
      );
      if (!isCurrent()) return;
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

  Future<Highlight> _addHighlightAgain(Highlight highlight) {
    final area = highlight.imageArea;
    if (highlight.kind == HighlightKind.imageArea && area != null) {
      return _highlightRepository.addImageAreaHighlight(
        sourceId: highlight.sourceId,
        sourceType: highlight.sourceType,
        pageIndex: area.pageIndex,
        x: area.x,
        y: area.y,
        width: area.width,
        height: area.height,
        note: highlight.note,
        progress: highlight.progress,
        chapterTitle: highlight.chapterTitle,
        color: highlight.color,
      );
    }
    return _highlightRepository.addHighlight(
      sourceId: highlight.sourceId,
      sourceType: highlight.sourceType,
      text: highlight.text,
      note: highlight.note,
      cfiRange: highlight.cfiRange,
      pageNumber: highlight.pageNumber,
      scrollOffset: highlight.scrollOffset,
      progress: highlight.progress,
      chapterTitle: highlight.chapterTitle,
      color: highlight.color,
    );
  }

  Highlight _withCreatedAt(Highlight highlight, DateTime createdAt) =>
      Highlight(
        id: highlight.id,
        sourceId: highlight.sourceId,
        sourceType: highlight.sourceType,
        text: highlight.text,
        kind: highlight.kind,
        note: highlight.note,
        cfiRange: highlight.cfiRange,
        imageArea: highlight.imageArea,
        pageNumber: highlight.pageNumber,
        scrollOffset: highlight.scrollOffset,
        progress: highlight.progress,
        chapterTitle: highlight.chapterTitle,
        color: highlight.color,
        createdAt: createdAt,
      );
}
