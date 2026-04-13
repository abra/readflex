/// Outcome of an article import attempt. Callers return this from the
/// `onImportArticle` callback so the sheet can show a reason-specific
/// error message instead of a generic "failed".
sealed class ArticleImportOutcome {
  const ArticleImportOutcome();

  const factory ArticleImportOutcome.success() = ArticleImportSuccess;

  const factory ArticleImportOutcome.failure(
    ArticleImportFailureReason reason,
  ) = ArticleImportFailure;
}

class ArticleImportSuccess extends ArticleImportOutcome {
  const ArticleImportSuccess();
}

class ArticleImportFailure extends ArticleImportOutcome {
  const ArticleImportFailure(this.reason);

  final ArticleImportFailureReason reason;
}

/// User-facing categories of article import failure.
///
/// Intentionally coarse: the sheet only needs enough to show a helpful
/// one-line message. Exact technical details stay in logs.
enum ArticleImportFailureReason {
  /// URL didn't parse.
  invalidUrl,

  /// Device offline / DNS / timeout — anything network-shaped.
  network,

  /// Site responded but with an error status.
  httpError,

  /// Fetched successfully but readability couldn't extract an article.
  noReadableContent,

  /// Import reached the repository but saving to disk or DB failed.
  storage,

  /// Catch-all for unexpected failures.
  unknown,
}
