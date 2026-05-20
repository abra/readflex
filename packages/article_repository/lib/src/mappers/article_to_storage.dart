import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

extension ArticleToStorage on Article {
  ArticlesTableCompanion toStorageModel() => ArticlesTableCompanion(
    id: Value(id),
    title: Value(title),
    url: Value(url),
    resolvedUrl: Value(resolvedUrl),
    canonicalUrl: Value(canonicalUrl),
    author: Value(author),
    siteName: Value(siteName),
    hostname: Value(hostname),
    description: Value(description),
    imageUrl: Value(imageUrl),
    coverImagePath: Value(
      coverImagePath != null ? p.basename(coverImagePath!) : null,
    ),
    language: Value(language),
    contentPath: Value(p.basename(contentPath)),
    plainText: Value(plainText),
    textLength: Value(textLength),
    estimatedWordCount: Value(estimatedWordCount),
    currentCfi: Value(currentCfi),
    readingProgress: Value(readingProgress),
    addedAt: Value(addedAt.toIso8601String()),
    lastOpenedAt: Value(lastOpenedAt?.toIso8601String()),
    isFinished: Value(isFinished),
  );
}
