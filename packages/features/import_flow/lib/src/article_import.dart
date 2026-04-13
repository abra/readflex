import 'package:article_parser/article_parser.dart';
import 'package:article_repository/article_repository.dart';
import 'package:monitoring/monitoring.dart';

import 'article_import_outcome.dart';

/// Parses a URL, fetches and cleans the article, and saves it to the
/// repository. Returns a typed [ArticleImportOutcome] so the UI can
/// show reason-specific error messages.
Future<ArticleImportOutcome> importArticle({
  required String url,
  required ArticleRepository articleRepository,
  required ArticleParser articleParser,
  required Logger logger,
}) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return const ArticleImportOutcome.failure(
      ArticleImportFailureReason.invalidUrl,
    );
  }

  final ParsedArticle parsed;
  try {
    parsed = await articleParser.parse(trimmed);
  } on ArticleParserException catch (e, st) {
    logger.warn(
      'Article parse failed for $trimmed (${e.reason})',
      error: e,
      stackTrace: st,
    );
    return ArticleImportOutcome.failure(_mapParserFailure(e.reason));
  } catch (e, st) {
    logger.warn(
      'Article parse threw unexpectedly for $trimmed',
      error: e,
      stackTrace: st,
    );
    return const ArticleImportOutcome.failure(
      ArticleImportFailureReason.unknown,
    );
  }

  try {
    await articleRepository.addArticle(
      title: parsed.title,
      url: trimmed,
      content: parsed.cleanedHtml,
      siteName: parsed.siteName,
      byline: parsed.byline,
      excerpt: parsed.excerpt,
      publishedTime: parsed.publishedTime,
      lang: parsed.lang,
      coverImageUrl: parsed.coverImageUrl,
      textLength: parsed.textLength,
      estimatedWordCount: parsed.estimatedWordCount,
    );
  } catch (e, st) {
    logger.warn(
      'Article persist failed for $trimmed',
      error: e,
      stackTrace: st,
    );
    return const ArticleImportOutcome.failure(
      ArticleImportFailureReason.storage,
    );
  }

  return const ArticleImportOutcome.success();
}

ArticleImportFailureReason _mapParserFailure(ArticleParserFailure reason) {
  return switch (reason) {
    ArticleParserFailure.invalidUrl => ArticleImportFailureReason.invalidUrl,
    ArticleParserFailure.network => ArticleImportFailureReason.network,
    ArticleParserFailure.httpStatus => ArticleImportFailureReason.httpError,
    ArticleParserFailure.noContent =>
      ArticleImportFailureReason.noReadableContent,
  };
}
