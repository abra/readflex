import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:reader_webview/reader_webview.dart';

part 'reader_event.dart';

part 'reader_state.dart';

const _traceReaderBuilds = bool.fromEnvironment(
  'READFLEX_TRACE_READER_BUILDS',
);

void _debugTraceReaderBloc(String message) {
  if (!_traceReaderBuilds || kReleaseMode) return;
  debugPrint('[reader-trace] $message');
}

/// Owns the loaded book and its highlights for the reader screen.
///
/// Responsibilities:
///   * resolve a [sourceId] into a [Book] on load and bump its
///     `lastOpenedAt` timestamp;
///   * persist position updates (CFI + progress fraction) coming from the
///     WebView back to the repository;
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
    SourceType initialSourceType = SourceType.book,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _highlightRepository = highlightRepository,
       super(
         initialSource == null
             ? const ReaderState()
             : ReaderState(
                 status: ReaderStatus.ready,
                 title: initialSource.title,
                 book: initialSource,
                 sourceType: initialSourceType,
                 pageProgressionRtl: _inferredBookPageProgressionRtl(
                   initialSource,
                 ),
               ),
       ) {
    on<ReaderSourceLoadRequested>(_onSourceLoadRequested);
    on<ReaderBookPositionUpdated>(_onBookPositionUpdated);
    on<ReaderHighlightsRefreshed>(_onHighlightsRefreshed);
    on<ReaderTocUpdated>(_onTocUpdated);
    on<ReaderDocumentFeaturesUpdated>(_onDocumentFeaturesUpdated);
    on<ReaderBookmarkChanged>(_onBookmarkChanged);
  }

  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  final HighlightRepository _highlightRepository;

  /// Pending Book to persist to the repository. foliate-js can emit frequent
  /// `ReaderBookPositionUpdated` events during navigation, so the actual
  /// `updateBook` write is debounced and SQLite is not hit on every
  /// `onRelocated`. State is still emitted on every event so UI stays in sync.
  Book? _pendingPersist;
  Timer? _persistTimer;
  static const _persistDebounce = Duration(milliseconds: 500);

  @override
  Future<void> close() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    // Flush whatever's pending so closing the reader (or hot
    // restart) doesn't drop the latest position. Awaited so the
    // write actually completes before the bloc's stream closes.
    final pending = _pendingPersist;
    _pendingPersist = null;
    if (pending != null) {
      try {
        await _persistReaderBook(pending);
      } catch (e, st) {
        addError(e, st);
      }
    }
    return super.close();
  }

  Future<void> _onSourceLoadRequested(
    ReaderSourceLoadRequested event,
    Emitter<ReaderState> emit,
  ) async {
    final hasInitialSource = state.book?.id == event.sourceId;
    if (!hasInitialSource) {
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

      if (book != null) {
        // Bump `lastOpenedAt` in BOTH the persisted row AND the
        // in-memory state. Earlier the emit kept the pre-bump
        // `book`, so the very first `_onBookPositionUpdated`
        // dispatched after open would copyWith on a stale
        // lastOpenedAt and overwrite the freshly-written value
        // back to its previous (often null) state — leaving the
        // book labelled "New" in the library forever.
        final updatedBook = book.copyWith(lastOpenedAt: DateTime.now());
        await _bookRepository.updateBook(updatedBook);
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            title: updatedBook.title,
            book: updatedBook,
            sourceType: SourceType.book,
            articleUrl: null,
            pageProgressionRtl: _inferredBookPageProgressionRtl(updatedBook),
            highlights: highlights,
            bookmarks: bookmarks,
            documentFeatures: null,
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
        await articleRepository.updateArticle(updatedArticle);
        final readerBook = articleRepository.toReaderBook(updatedArticle);
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            title: readerBook.title,
            book: readerBook,
            sourceType: SourceType.article,
            articleUrl: updatedArticle.url,
            pageProgressionRtl: _inferredArticlePageProgressionRtl(
              updatedArticle,
            ),
            highlights: highlights,
            bookmarks: bookmarks,
            documentFeatures: null,
          ),
        );
        return;
      }

      emit(state.copyWith(status: ReaderStatus.failure));
    } catch (e, st) {
      addError(e, st);
      if (!hasInitialSource) {
        emit(state.copyWith(status: ReaderStatus.failure));
      }
    }
  }

  /// Persists a CFI + progress fraction emitted by the WebView for the
  /// currently-open book.
  ///
  /// foliate-js can occasionally report a fraction slightly above 1.0
  /// (overshoot at end-of-content / re-entry); we clamp to `[0, 1]` so
  /// the library cover's progress pill stays sensible.
  Future<void> _onBookPositionUpdated(
    ReaderBookPositionUpdated event,
    Emitter<ReaderState> emit,
  ) async {
    if (state.book == null) return;

    // foliate-js's paginator allows navigation onto two blank trailing
    // columns past the actual content (`atEnd: page >= pages - 2`).
    // On those pages it reports `progress=0` / `bookCurrentPage=0` —
    // not because we're at the start, but because there's no real
    // content under the viewport. Use the paginator-reported `atEnd`
    // signal to override the bogus numbers with the canonical
    // "we're at the very end" values, the same trick readest uses.
    final total = event.bookTotalPages;
    final isPhantomEnd = event.atEnd && total != null && total > 0;
    final isSinglePageArticle =
        state.sourceType == SourceType.article && total == 1;
    final clampedProgress = event.progress.clamp(0.0, 1.0).toDouble();
    final progress = isPhantomEnd || isSinglePageArticle
        ? 1.0
        : _articleVisiblePageProgress(
            sourceType: state.sourceType,
            progress: clampedProgress,
            bookCurrentPage: event.bookCurrentPage,
            bookTotalPages: event.bookTotalPages,
            chapterCurrentPage: event.chapterCurrentPage,
            chapterTotalPages: event.chapterTotalPages,
          );
    final bookCurrentPage = isPhantomEnd ? total - 1 : event.bookCurrentPage;

    final updated = state.book!.copyWith(
      currentCfi: event.cfi,
      readingProgress: progress,
    );
    final previousProgress = state.book?.readingProgress ?? 0;
    final nextSizeTotal = event.sizeTotal ?? state.sizeTotal;
    final hasMeaningfulChange =
        updated != state.book ||
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
        state.currentPageBookmarked != event.currentPageBookmarked ||
        state.currentPageBookmarkCfi != event.currentPageBookmarkCfi ||
        state.currentPageBookmarkId != event.currentPageBookmarkId;
    if (!hasMeaningfulChange) return;

    // Emit immediately so chrome stays in sync with the WebView.
    // `sizeTotal` is constant per book; cache the first non-null value and
    // never overwrite it back to null on subsequent emits.
    emit(
      state.copyWith(
        book: updated,
        chapterTitle: event.chapterTitle,
        bookCurrentPage: bookCurrentPage,
        bookTotalPages: event.bookTotalPages,
        chapterCurrentPage: event.chapterCurrentPage,
        chapterTotalPages: event.chapterTotalPages,
        sizeTotal: nextSizeTotal,
        pageProgressionRtl: event.pageProgressionRtl,
        atStart: event.atStart,
        atEnd: event.atEnd,
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
    final isFirstArticleProgress =
        state.sourceType == SourceType.article &&
        previousProgress <= 0 &&
        progress > 0;
    if (isFirstArticleProgress) {
      _persistTimer?.cancel();
      _persistTimer = null;
      _pendingPersist = null;
      await _persistReaderBook(updated);
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
      await _persistReaderBook(pending);
    } catch (e, st) {
      addError(e, st);
    }
  }

  Future<void> _persistReaderBook(Book book) async {
    if (state.sourceType == SourceType.article) {
      final articleRepository = _articleRepository;
      if (articleRepository == null) return;
      final article = await articleRepository.getArticleById(book.id);
      if (article == null) return;
      await articleRepository.updateArticle(
        articleRepository.updateFromReaderBook(article, book),
      );
      return;
    }
    await _bookRepository.updateBook(book);
  }

  /// Routes an external error through BLoC's error pipeline (e.g. from a
  /// widget that detects a failure but cannot emit state itself).
  void reportError(Object error, StackTrace stackTrace) =>
      addError(error, stackTrace);

  Future<void> _onHighlightsRefreshed(
    ReaderHighlightsRefreshed event,
    Emitter<ReaderState> emit,
  ) async {
    final sourceId = state.sourceId;
    if (sourceId == null) return;
    try {
      final highlights = await _highlightRepository.getHighlightsBySource(
        sourceId,
      );
      emit(state.copyWith(highlights: highlights));
    } catch (e, st) {
      addError(e, st);
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
    Emitter<ReaderState> emit,
  ) async {
    final book = state.book;
    if (book == null) return;

    try {
      if (event.remove) {
        final bookmarkId = event.id;
        final hasBookmarkId = bookmarkId != null && bookmarkId.isNotEmpty;
        if (!hasBookmarkId && event.cfi.isEmpty) return;

        if (hasBookmarkId) {
          await _bookRepository.deleteBookmarkById(book.id, bookmarkId);
        } else {
          await _bookRepository.deleteBookmarkBySourceAndCfi(
            book.id,
            event.cfi,
          );
        }

        final removedCurrentBookmark = hasBookmarkId
            ? state.currentPageBookmarkId == bookmarkId
            : state.currentPageBookmarkCfi == event.cfi;
        emit(
          state.copyWith(
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
        sourceId: book.id,
        sourceType: state.sourceType,
        cfi: event.cfi,
        content: event.content,
        progress: event.progress,
        chapterTitle: state.chapterTitle,
        anchorExact: event.anchorExact,
        anchorPrefix: event.anchorPrefix,
        anchorSuffix: event.anchorSuffix,
        anchorSectionIndex: event.anchorSectionIndex,
        anchorSectionPage: event.anchorSectionPage,
      );
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
          currentPageBookmarked: true,
          currentPageBookmarkCfi: bookmark.cfi,
          currentPageBookmarkId: bookmark.id,
        ),
      );
    } catch (e, st) {
      addError(e, st);
    }
  }
}

double _articleVisiblePageProgress({
  required SourceType sourceType,
  required double progress,
  required int? bookCurrentPage,
  required int? bookTotalPages,
  required int? chapterCurrentPage,
  required int? chapterTotalPages,
}) {
  if (sourceType != SourceType.article || progress > 0) return progress;

  final totalPages =
      _positivePageTotal(bookTotalPages) ??
      _positivePageTotal(chapterTotalPages);
  if (totalPages == null || totalPages <= 1) return progress;

  final currentPage =
      _visibleArticlePage(bookCurrentPage) ??
      _visibleArticlePage(chapterCurrentPage) ??
      1;
  return (currentPage / totalPages).clamp(0.0, 1.0).toDouble();
}

int? _positivePageTotal(int? value) {
  if (value == null || value <= 0) return null;
  return value;
}

int? _visibleArticlePage(int? value) {
  if (value == null) return null;
  return value < 1 ? 1 : value;
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
