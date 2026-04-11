import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

extension ArticleToStorage on Article {
  /// Produces an [ArticlesTableCompanion] for persistence. Path fields in
  /// the domain model are absolute; this mapper strips the directory
  /// prefix so the DB only stores filenames. See [ArticleToDomain] for
  /// why (iOS Documents UUID instability).
  ArticlesTableCompanion toStorageModel() => ArticlesTableCompanion(
    id: Value(id),
    title: Value(title),
    siteName: Value(siteName),
    byline: Value(byline),
    excerpt: Value(excerpt),
    publishedTime: Value(publishedTime),
    lang: Value(lang),
    url: Value(url),
    contentPath: Value(p.basename(contentPath)),
    coverImageUrl: Value(coverImageUrl),
    coverImagePath: Value(
      coverImagePath != null ? p.basename(coverImagePath!) : null,
    ),
    textLength: Value(textLength),
    estimatedWordCount: Value(estimatedWordCount),
    currentScrollOffset: Value(currentScrollOffset),
    addedAt: Value(addedAt.toIso8601String()),
    lastOpenedAt: Value(lastOpenedAt?.toIso8601String()),
    isFinished: Value(isFinished),
  );
}
