import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension ArticleToStorage on Article {
  ArticlesTableCompanion toStorageModel() => ArticlesTableCompanion(
    id: Value(id),
    title: Value(title),
    siteName: Value(siteName),
    byline: Value(byline),
    excerpt: Value(excerpt),
    publishedTime: Value(publishedTime),
    lang: Value(lang),
    url: Value(url),
    contentPath: Value(contentPath),
    coverImageUrl: Value(coverImageUrl),
    coverImagePath: Value(coverImagePath),
    textLength: Value(textLength),
    estimatedWordCount: Value(estimatedWordCount),
    currentScrollOffset: Value(currentScrollOffset),
    addedAt: Value(addedAt.toIso8601String()),
    lastOpenedAt: Value(lastOpenedAt?.toIso8601String()),
    isFinished: Value(isFinished),
  );
}
