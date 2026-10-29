import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'reader_document_features.dart';
import 'reader_position.dart';
import 'reader_progress_label.dart';
import 'reader_toc_item.dart';

part 'reader_event.dart';

part 'reader_document.dart';

part 'reader_state.dart';
part 'reader_bookmark_operations.dart';
part 'reader_highlight_operations.dart';

// Shares the reader trace flag with the screen so bloc events align with UI logs.
const _traceReaderBuilds = bool.fromEnvironment(
  'READFLEX_TRACE_READER_BUILDS',
);

void _debugTraceReaderBloc(String message) {
  if (!_traceReaderBuilds || kReleaseMode) return;
  debugPrint('[reader-trace] $message');
}

void _debugTraceReaderHighlightBloc(String message) {
  if (!kDebugMode) return;
  debugPrint('[reader-highlight] $message');
}

Highlight? _highlightById(List<Highlight> highlights, String id) {
  for (final highlight in highlights) {
    if (highlight.id == id) return highlight;
  }
  return null;
}

String? _normalizedHighlightNote(String? note) {
  final normalized = note?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

/// Owns the loaded source document and its highlights for the reader screen.
///
/// Responsibilities:
///   * resolve a [sourceId] into a reader document on load and bump its
///     `lastOpenedAt` timestamp;
///   * persist position updates (CFI + progress fraction) coming from the
///     page surface back to the repository, reporting each saved write through
///     `onReadingPositionSaved`;
///   * refresh highlights when a TextAction (e.g. "Highlight") completes.
///
/// UI-only concerns (chrome/drawer state, search drawer state, selection,
/// selection) live in separate cubits — see [ReaderUiCubit],
/// [ReaderSearchCubit], and [ReaderSelectionCubit].
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc({
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
    ArticleRepository? articleRepository,
    Book? initialSource,
    ValueChanged<double>? onReadingPositionSaved,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _highlightRepository = highlightRepository,
       _onReadingPositionSaved = onReadingPositionSaved,
       super(
         initialSource == null
             ? const ReaderState()
             : ReaderState(
                 status: ReaderStatus.ready,
                 title: initialSource.title,
                 document: ReaderDocument.fromBook(initialSource),
                 sourceType: SourceType.book,
                 pageProgressionRtl: _inferredBookPageProgressionRtl(
                   initialSource,
                 ),
               ),
       ) {
    on<ReaderSourceLoadRequested>(_onSourceLoadRequested);
    on<ReaderSurfaceFailed>((event, emit) {
      if (event.sourceId != state.sourceId) return;
      _loadGeneration++;
      addError(event.error, event.stackTrace ?? StackTrace.current);
      emit(state.copyWith(status: ReaderStatus.failure));
    });
    on<ReaderBookPositionUpdated>(_onBookPositionUpdated);
    on<ReaderHighlightEvent>(
      _onHighlightEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<ReaderTocUpdated>(_onTocUpdated);
    on<ReaderDocumentFeaturesUpdated>(_onDocumentFeaturesUpdated);
    on<ReaderBookmarkEvent>(
      _onBookmarkEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  final HighlightRepository _highlightRepository;

  /// Called with the saved progress after each position write reaches the
  /// repository, including the flush on [close], so the screen below can
  /// update while the reader still covers it.
  final ValueChanged<double>? _onReadingPositionSaved;

  /// Pending document to persist to the repository. Surfaces report every
  /// move (`ReaderBookPositionUpdated`), so the actual repository write is
  /// debounced and SQLite is not hit on every page turn. State is still
  /// emitted on every event so UI stays in sync.
  ReaderDocument? _pendingPersist;
  Timer? _persistTimer;
  Future<void>? _persistenceTail;
  Future<void>? _closeFuture;
  int _loadGeneration = 0;
  int _highlightRevision = 0;
  int _bookmarkRevision = 0;
  int _positionRevision = 0;
  int _highlightEffectVersion = 0;
  String? _livePositionSourceId;
  final _highlightDeletions = <String, HighlightDeletion>{};
  static const _persistDebounce = Duration(milliseconds: 500);

  @override
  Future<void> close() {
    final closing = _closeFuture;
    if (closing != null) return closing;
    _loadGeneration++;
    return _closeFuture = _finishClose(super.close());
  }

  Future<void> _finishClose(Future<void> closing) async {
    await closing;
    _highlightDeletions.clear();
    _persistTimer?.cancel();
    _persistTimer = null;
    await _flushPersist();
    // A timer may already have consumed the pending value; drain its write too.
    final activeWrite = _persistenceTail;
    if (activeWrite != null) await activeWrite;
  }

  Future<void> _onSourceLoadRequested(
    ReaderSourceLoadRequested event,
    Emitter<ReaderState> emit,
  ) async {
    final generation = ++_loadGeneration;
    final highlightRevision = _highlightRevision;
    final bookmarkRevision = _bookmarkRevision;
    final hasInitialSource = state.document?.id == event.sourceId;
    if (!hasInitialSource) _highlightDeletions.clear();
    final hasUsableSource =
        hasInitialSource && state.status == ReaderStatus.ready;
    if (!hasUsableSource) {
      emit(state.copyWith(status: ReaderStatus.loading));
    }

    try {
      final (book, article, highlights, bookmarks) = await (
        _bookRepository.getBookById(event.sourceId),
        _articleRepository?.getArticleById(event.sourceId) ??
            Future.value(null),
        _highlightRepository.getHighlightsBySource(event.sourceId),
        _bookRepository.getBookmarksBySource(event.sourceId),
      ).wait;

      if (emit.isDone || generation != _loadGeneration) return;

      if (book != null) {
        final updatedBook = book.copyWith(lastOpenedAt: DateTime.now());
        await _enqueuePersistence(
          () => _bookRepository.markOpened(book.id, updatedBook.lastOpenedAt!),
        );
        if (emit.isDone || generation != _loadGeneration) return;
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            title: updatedBook.title,
            document: _mergeLoadedPosition(
              ReaderDocument.fromBook(updatedBook),
            ),
            sourceType: SourceType.book,
            articleUrl: null,
            pageProgressionRtl: hasInitialSource
                ? state.pageProgressionRtl
                : _inferredBookPageProgressionRtl(updatedBook),
            highlights:
                hasInitialSource && highlightRevision != _highlightRevision
                ? state.highlights
                : highlights,
            bookmarks: hasInitialSource && bookmarkRevision != _bookmarkRevision
                ? state.bookmarks
                : bookmarks,
            bookmarkEdits: hasInitialSource
                ? state.bookmarkEdits
                : const ReaderBookmarkEdits(),
            highlightEdits: hasInitialSource
                ? state.highlightEdits
                : const ReaderHighlightEdits(),
            documentFeatures: hasInitialSource ? state.documentFeatures : null,
          ),
        );
        return;
      }

      if (article != null) {
        final updatedArticle = article.copyWith(lastOpenedAt: DateTime.now());
        final articleRepository = _articleRepository;
        if (articleRepository == null) {
          emit(state.copyWith(status: ReaderStatus.failure));
          return;
        }
        await _enqueuePersistence(
          () => articleRepository.markOpened(
            article.id,
            updatedArticle.lastOpenedAt!,
          ),
        );
        if (emit.isDone || generation != _loadGeneration) return;
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            title: updatedArticle.title,
            document: _mergeLoadedPosition(
              ReaderDocument.fromArticle(updatedArticle),
            ),
            sourceType: SourceType.article,
            bookmarkEdits: hasInitialSource
                ? state.bookmarkEdits
                : const ReaderBookmarkEdits(),
            highlightEdits: hasInitialSource
                ? state.highlightEdits
                : const ReaderHighlightEdits(),
            articleUrl: updatedArticle.url,
            pageProgressionRtl: _inferredArticlePageProgressionRtl(
              updatedArticle,
            ),
            highlights:
                hasInitialSource && highlightRevision != _highlightRevision
                ? state.highlights
                : highlights,
            bookmarks: hasInitialSource && bookmarkRevision != _bookmarkRevision
                ? state.bookmarks
                : bookmarks,
            documentFeatures: hasInitialSource ? state.documentFeatures : null,
          ),
        );
        return;
      }

      emit(state.copyWith(status: ReaderStatus.failure));
    } catch (e, st) {
      addError(e, st);
      if (!emit.isDone && generation == _loadGeneration && !hasUsableSource) {
        emit(state.copyWith(status: ReaderStatus.failure));
      }
    }
  }

  ReaderDocument _mergeLoadedPosition(ReaderDocument loaded) {
    final current = state.document;
    if (current?.id != loaded.id || _livePositionSourceId != loaded.id) {
      return loaded;
    }
    return loaded.copyWith(
      currentCfi: current!.currentCfi,
      readingProgress: current.readingProgress,
    );
  }

  /// Persists a CFI + progress fraction the page surface reported for the
  /// currently-open reader document, clamped to `[0, 1]` so the library
  /// cover's progress pill stays sensible.
  Future<void> _onBookPositionUpdated(
    ReaderBookPositionUpdated event,
    Emitter<ReaderState> emit,
  ) async {
    final document = state.document;
    if (document == null) return;
    // The last page reads 100%: its fraction is where the page starts.
    final total = event.bookTotalPages;
    final atLastPage = event.atEnd && total != null && total > 0;
    final progress = atLastPage ? 1.0 : _clampProgress(event.progress);
    final bookCurrentPage = atLastPage ? total - 1 : event.bookCurrentPage;

    final updated = document.copyWith(
      currentCfi: event.cfi,
      readingProgress: progress,
    );
    final previousProgress = document.readingProgress;
    final nextSizeTotal = event.sizeTotal ?? state.sizeTotal;
    final hasMeaningfulChange =
        updated != document ||
        state.chapterTitle != event.chapterTitle ||
        state.bookCurrentPage != bookCurrentPage ||
        state.bookTotalPages != event.bookTotalPages ||
        state.chapterCurrentPage != event.chapterCurrentPage ||
        state.chapterTotalPages != event.chapterTotalPages ||
        state.sizeTotal != nextSizeTotal ||
        (event.pageProgressionRtl != null &&
            state.pageProgressionRtl != event.pageProgressionRtl) ||
        state.atStart != event.atStart ||
        state.atEnd != event.atEnd ||
        state.minutesLeft != event.minutesLeft ||
        state.currentPageBookmarked != event.currentPageBookmarked ||
        state.currentPageBookmarkCfi != event.currentPageBookmarkCfi ||
        state.currentPageBookmarkId != event.currentPageBookmarkId;
    if (!hasMeaningfulChange) return;
    _positionRevision++;
    _livePositionSourceId = document.id;

    // Emit immediately so chrome stays in sync with the page.
    // `sizeTotal` is constant per book; cache the first non-null value and
    // never overwrite it back to null on subsequent emits.
    emit(
      state.copyWith(
        document: updated,
        chapterTitle: event.chapterTitle,
        bookCurrentPage: bookCurrentPage,
        bookTotalPages: event.bookTotalPages,
        chapterCurrentPage: event.chapterCurrentPage,
        chapterTotalPages: event.chapterTotalPages,
        sizeTotal: nextSizeTotal,
        pageProgressionRtl: event.pageProgressionRtl,
        atStart: event.atStart,
        atEnd: event.atEnd,
        minutesLeft: event.minutesLeft,
        currentPageBookmarked: event.currentPageBookmarked,
        currentPageBookmarkCfi: event.currentPageBookmarkCfi,
        currentPageBookmarkId: event.currentPageBookmarkId,
      ),
    );
    _debugTraceReaderBloc(
      'ReaderBookPositionUpdated emit '
      'progress=${progress.toStringAsFixed(3)} '
      'bookPage=$bookCurrentPage/${event.bookTotalPages} '
      'chapterPage=${event.chapterCurrentPage}/${event.chapterTotalPages} '
      'atStart=${event.atStart} '
      'atEnd=${event.atEnd} '
      'rtl=${event.pageProgressionRtl}',
    );
    // The first progress is saved at once: it is what puts the source in the
    // Library's Continue reading card.
    final isFirstProgress = previousProgress <= 0 && progress > 0;
    if (isFirstProgress) {
      _persistTimer?.cancel();
      _persistTimer = null;
      _pendingPersist = null;
      await _enqueuePersistence(() => _persistReaderDocument(updated));
      return;
    }

    // Persist with a trailing debounce — successive emits within the
    // window only update [_pendingPersist], so a 5-second drag that
    // fires ~50 onRelocated events still results in one write at the
    // end. The latest pending value is always the one persisted.
    _pendingPersist = updated;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _flushPersist);
  }

  Future<void> _flushPersist() async {
    _persistTimer = null;
    final pending = _pendingPersist;
    if (pending == null) return;
    _pendingPersist = null;
    try {
      await _enqueuePersistence(() => _persistReaderDocument(pending));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _enqueuePersistence(Future<void> Function() write) {
    final previous = _persistenceTail;
    final operation = previous == null
        ? Future<void>.sync(write)
        : previous.then((_) => write());
    late final Future<void> tail;
    void clearIfSettled() {
      if (identical(_persistenceTail, tail)) _persistenceTail = null;
    }

    // The caller reports the error; the queue must still accept later writes.
    tail = operation.then<void>(
      (_) => clearIfSettled(),
      onError: (Object _, StackTrace _) => clearIfSettled(),
    );
    _persistenceTail = tail;
    return operation;
  }

  Future<void> _persistReaderDocument(ReaderDocument document) async {
    if (document.sourceType == SourceType.article) {
      final articleRepository = _articleRepository;
      if (articleRepository == null) return;
      await articleRepository.updateReadingPosition(
        document.id,
        cfi: document.currentCfi,
        progress: document.readingProgress,
      );
    } else {
      await _bookRepository.updateReadingPosition(
        document.id,
        cfi: document.currentCfi,
        progress: document.readingProgress,
      );
    }
    _onReadingPositionSaved?.call(document.readingProgress);
  }

  /// Routes an external error through BLoC's error pipeline (e.g. from a
  /// widget that detects a failure but cannot emit state itself).
  void reportError(Object error, StackTrace stackTrace) =>
      addError(error, stackTrace);

  Future<void> _onHighlightEvent(
    ReaderHighlightEvent event,
    Emitter<ReaderState> emit,
  ) async {
    final sourceId = state.sourceId;
    if (sourceId == null) return;
    bool isCurrent() => !emit.isDone && state.sourceId == sourceId;
    final operation = switch (event) {
      ReaderHighlightsRefreshed() ||
      ReaderHighlightRestored() ||
      ReaderHighlightUndoDismissed() => null,
      ReaderHighlightColorChangeRequested() => ReaderHighlightOperation.color,
      ReaderHighlightNoteChangeRequested() => ReaderHighlightOperation.note,
      ReaderHighlightDeleteRequested() => ReaderHighlightOperation.delete,
    };
    Future<void> Function()? write;
    Highlight? undoHighlight;
    switch (event) {
      case ReaderHighlightsRefreshed():
        break;
      case ReaderHighlightUndoDismissed():
        _highlightDeletions.clear();
        emit(state.copyWith(highlightEdits: const ReaderHighlightEdits()));
        return;
      case ReaderHighlightRestored(:final highlightId):
        await _restoreHighlight(highlightId, sourceId, emit);
        return;
      case ReaderHighlightColorChangeRequested(
        :final highlightId,
        :final color,
      ):
        final highlight = _highlightById(state.highlights, highlightId);
        if (highlight == null || highlight.color == color) return;
        write = () =>
            _highlightRepository.updateHighlightColor(highlightId, color);
      case ReaderHighlightNoteChangeRequested(:final highlightId, :final note):
        final normalized = _normalizedHighlightNote(note);
        final highlight = _highlightById(state.highlights, highlightId);
        if (highlight == null ||
            _normalizedHighlightNote(highlight.note) == normalized) {
          return;
        }
        write = () =>
            _highlightRepository.updateHighlightNote(highlightId, normalized);
      case ReaderHighlightDeleteRequested(:final highlightId):
        // Unknown ids are still deleted; only a known row gets an Undo entry.
        write = () async {
          final deletion = await _highlightRepository.deleteHighlightForUndo(
            highlightId,
          );
          if (deletion != null && isCurrent()) {
            _highlightDeletions[highlightId] = deletion;
            undoHighlight = deletion.highlight;
          }
        };
    }

    ReaderHighlightEffect? effect(bool success) => operation == null
        ? null
        : ReaderHighlightEffect(
            version: ++_highlightEffectVersion,
            operation: operation,
            success: success,
          );

    try {
      if (write != null) await write();
      final highlights = await _highlightRepository.getHighlightsBySource(
        sourceId,
      );
      if (!isCurrent()) return;
      // Only published data invalidates an older source-load snapshot.
      _highlightRevision++;
      _debugTraceReaderHighlightBloc(
        'refresh-success source=$sourceId count=${highlights.length}',
      );
      final deletedHighlight = undoHighlight;
      emit(
        state.copyWith(
          highlights: highlights,
          highlightEffect: effect(true),
          highlightEdits: deletedHighlight == null
              ? state.highlightEdits
              : ReaderHighlightEdits(
                  removed: [
                    for (final h in state.highlightEdits.removed)
                      if (h.id != deletedHighlight.id) h,
                    deletedHighlight,
                  ],
                  busyId: state.highlightEdits.busyId,
                  failedId: state.highlightEdits.failedId,
                ),
        ),
      );
    } catch (e, st) {
      addError(e, st);
      if (isCurrent() && operation != null) {
        emit(state.copyWith(highlightEffect: effect(false)));
      }
    }
  }

  void _onTocUpdated(ReaderTocUpdated event, Emitter<ReaderState> emit) {
    emit(state.copyWith(tocItems: event.items));
  }

  void _onDocumentFeaturesUpdated(
    ReaderDocumentFeaturesUpdated event,
    Emitter<ReaderState> emit,
  ) {
    emit(state.copyWith(documentFeatures: event.features));
  }

  Future<void> _onBookmarkChanged(
    ReaderBookmarkChanged event,
    Emitter<ReaderState> emit, {
    SourceBookmark? undoBookmark,
  }) async {
    final document = state.document;
    if (document == null) return;
    final positionRevision = _positionRevision;

    try {
      if (event.remove) {
        final bookmarkId = event.id;
        final hasBookmarkId = bookmarkId != null && bookmarkId.isNotEmpty;
        if (!hasBookmarkId && event.cfi.isEmpty) return;

        if (hasBookmarkId) {
          await _bookRepository.deleteBookmarkById(document.id, bookmarkId);
        } else {
          await _bookRepository.deleteBookmarkBySourceAndCfi(
            document.id,
            event.cfi,
          );
        }

        if (emit.isDone || state.sourceId != document.id) return;
        _bookmarkRevision++;
        final removedCurrentBookmark = hasBookmarkId
            ? state.currentPageBookmarkId == bookmarkId
            : state.currentPageBookmarkCfi == event.cfi;
        emit(
          state.copyWith(
            bookmarkEdits: undoBookmark == null
                ? state.bookmarkEdits
                : ReaderBookmarkEdits(
                    removed: [...state.bookmarkEdits.removed, undoBookmark],
                  ),
            bookmarks: [
              for (final bookmark in state.bookmarks)
                if (hasBookmarkId
                    ? bookmark.id != bookmarkId
                    : bookmark.cfi != event.cfi)
                  bookmark,
            ],
            currentPageBookmarked: removedCurrentBookmark
                ? false
                : state.currentPageBookmarked,
            currentPageBookmarkCfi: removedCurrentBookmark
                ? null
                : state.currentPageBookmarkCfi,
            currentPageBookmarkId: removedCurrentBookmark
                ? null
                : state.currentPageBookmarkId,
          ),
        );
        return;
      }

      if (event.cfi.isEmpty) return;

      final bookmark = await _bookRepository.addBookmark(
        sourceId: document.id,
        sourceType: state.sourceType,
        cfi: event.cfi,
        content: event.content,
        progress: event.progress,
        chapterTitle: isImagePageFormat(document.format)
            ? null
            : state.chapterTitle,
        anchorExact: event.anchorExact,
        anchorPrefix: event.anchorPrefix,
        anchorSuffix: event.anchorSuffix,
        anchorSectionIndex: event.anchorSectionIndex,
        anchorSectionPage: event.anchorSectionPage,
        anchorVersion: event.anchorVersion,
      );
      if (emit.isDone || state.sourceId != document.id) return;
      _bookmarkRevision++;
      final stayedOnPage = positionRevision == _positionRevision;
      final next =
          [
            for (final existing in state.bookmarks)
              if (existing.id != bookmark.id) existing,
            bookmark,
          ]..sort((a, b) {
            final byProgress = a.progress.compareTo(b.progress);
            if (byProgress != 0) return byProgress;
            return a.createdAt.compareTo(b.createdAt);
          });
      emit(
        state.copyWith(
          bookmarks: next,
          currentPageBookmarked: stayedOnPage
              ? true
              : state.currentPageBookmarked,
          currentPageBookmarkCfi: stayedOnPage
              ? bookmark.cfi
              : state.currentPageBookmarkCfi,
          currentPageBookmarkId: stayedOnPage
              ? bookmark.id
              : state.currentPageBookmarkId,
        ),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}

double _clampProgress(double progress) {
  if (!progress.isFinite) return 0;
  if (progress < 0) return 0;
  if (progress > 1) return 1;
  return progress;
}

bool _inferredBookPageProgressionRtl(Book book) {
  return inferArticleTextDirectionFromText(
        [book.title, book.author].nonNulls.join(' '),
      ) ==
      ArticleTextDirection.rtl;
}

bool _inferredArticlePageProgressionRtl(Article article) {
  return (articleTextDirectionForLanguage(article.language) ??
          inferArticleTextDirectionFromText(
            [
              article.title,
              article.author,
              article.siteName,
              article.hostname,
              article.plainText,
            ].nonNulls.join(' '),
          )) ==
      ArticleTextDirection.rtl;
}
