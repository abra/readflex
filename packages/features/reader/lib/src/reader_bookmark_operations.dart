part of 'reader_bloc.dart';

extension _ReaderBookmarkOperations on ReaderBloc {
  Future<void> _onBookmarkEvent(
    ReaderBookmarkEvent event,
    Emitter<ReaderState> emit,
  ) async {
    switch (event) {
      case ReaderBookmarkChanged():
        await _onBookmarkChanged(event, emit);
      case ReaderBookmarkUndoDismissed():
        emit(state.copyWith(bookmarkEdits: const ReaderBookmarkEdits()));
      case ReaderBookmarkDeleted(:final sourceId, :final id):
        if (state.sourceId != sourceId) return;
        final bookmark = state.bookmarks.where((b) => b.id == id).firstOrNull;
        if (bookmark == null) return;
        final removed = state.bookmarkEdits.removed;
        emit(
          state.copyWith(
            bookmarkEdits: ReaderBookmarkEdits(removed: removed, busyId: id),
          ),
        );
        await _onBookmarkChanged(
          ReaderBookmarkChanged(
            remove: true,
            id: id,
            cfi: bookmark.cfi,
            content: bookmark.content,
            progress: bookmark.progress,
          ),
          emit,
          undoBookmark: bookmark,
        );
        if (emit.isDone || state.sourceId != sourceId) return;
        final failed = state.bookmarks.any((b) => b.id == id);
        if (failed) {
          emit(
            state.copyWith(
              bookmarkEdits: ReaderBookmarkEdits(
                removed: removed,
                failedId: id,
              ),
            ),
          );
        }
      case ReaderBookmarkRestored(:final sourceId, :final id):
        if (state.sourceId != sourceId) return;
        final removed = state.bookmarkEdits.removed;
        final bookmark = removed.where((b) => b.id == id).firstOrNull;
        if (bookmark == null) return;
        emit(
          state.copyWith(
            bookmarkEdits: ReaderBookmarkEdits(removed: removed, busyId: id),
          ),
        );
        try {
          final restored = await _bookRepository.restoreBookmark(bookmark);
          if (emit.isDone || state.sourceId != sourceId) return;
          _bookmarkRevision++;
          final bookmarks =
              [
                for (final b in state.bookmarks)
                  if (b.id != restored.id) b,
                restored,
              ]..sort((a, b) {
                final progress = a.progress.compareTo(b.progress);
                return progress == 0
                    ? a.createdAt.compareTo(b.createdAt)
                    : progress;
              });
          emit(
            state.copyWith(
              bookmarks: bookmarks,
              bookmarkEdits: ReaderBookmarkEdits(
                removed: [
                  for (final b in removed)
                    if (b.id != id) b,
                ],
              ),
            ),
          );
        } catch (error, stack) {
          reportError(error, stack);
          if (emit.isDone || state.sourceId != sourceId) return;
          emit(
            state.copyWith(
              bookmarkEdits: ReaderBookmarkEdits(
                removed: removed,
                failedId: id,
              ),
            ),
          );
        }
    }
  }
}
