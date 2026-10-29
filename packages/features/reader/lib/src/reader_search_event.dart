/// A whole-document search match.
///
/// [cfi] is the exact target accepted by `ReaderSurface.goToSearchResult`;
/// [chapterTitle] is best-effort context from the table of contents.
class ReaderSearchResult {
  const ReaderSearchResult({
    required this.cfi,
    required this.excerpt,
    this.chapterTitle,
  });

  final String cfi;
  final ReaderSearchExcerpt excerpt;
  final String? chapterTitle;
}

/// Streaming search event of a page surface.
///
/// Surfaces send progress and result batches as they scan sections, so the
/// search panel renders partial results instead of waiting for a full-book
/// search to finish.
sealed class ReaderSearchEvent {
  const ReaderSearchEvent({required this.requestId});

  final int requestId;
}

final class ReaderSearchProgress extends ReaderSearchEvent {
  const ReaderSearchProgress({
    required super.requestId,
    required this.progress,
  });

  final double progress;
}

final class ReaderSearchResults extends ReaderSearchEvent {
  const ReaderSearchResults({
    required super.requestId,
    required this.results,
  });

  final List<ReaderSearchResult> results;
}

final class ReaderSearchDone extends ReaderSearchEvent {
  const ReaderSearchDone({required super.requestId});
}

final class ReaderSearchError extends ReaderSearchEvent {
  const ReaderSearchError({
    required super.requestId,
    required this.message,
  });

  final String message;
}

/// Text around a search match, split so the panel can emphasize only the
/// matched fragment.
class ReaderSearchExcerpt {
  const ReaderSearchExcerpt({
    this.pre = '',
    this.match = '',
    this.post = '',
  });

  final String pre;
  final String match;
  final String post;
}
