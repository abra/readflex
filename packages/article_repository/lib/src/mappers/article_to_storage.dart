import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:domain_models/domain_models.dart';

extension ArticleToStorage on Article {
  ArticlesTableCompanion toStorageModel() => ArticlesTableCompanion(
    id: Value(id),
    title: Value(title),
    siteName: Value(siteName),
    url: Value(url),
    cleanedHtml: Value(cleanedHtml),
    coverImageUrl: Value(coverImageUrl),
    estimatedWordCount: Value(estimatedWordCount),
    currentScrollOffset: Value(currentScrollOffset),
    addedAt: Value(addedAt.toIso8601String()),
    lastOpenedAt: Value(lastOpenedAt?.toIso8601String()),
    isFinished: Value(isFinished),
  );
}
