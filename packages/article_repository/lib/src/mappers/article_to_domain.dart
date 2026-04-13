import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

extension ArticleToDomain on ArticlesTableData {
  /// Hydrates a domain [Article] from a DB row. Each article lives in its
  /// own directory: `articlesDir/<id>/`. The DB stores just filenames
  /// (`content.html`, `cover.png`); this mapper resolves those against the
  /// per-article directory so the domain model always exposes absolute paths.
  ///
  /// Why filename-only in the DB: iOS reassigns the app's Documents
  /// directory UUID on every clean reinstall, which makes any absolute
  /// path persisted in SQLite stale on the next launch. Storing just the
  /// filename and resolving at read time sidesteps that entirely.
  Article toDomainModel({required Directory articlesDir}) {
    final articleDir = p.join(articlesDir.path, id);
    return Article(
      id: id,
      title: title,
      siteName: siteName,
      byline: byline,
      excerpt: excerpt,
      publishedTime: publishedTime,
      lang: lang,
      url: url,
      contentPath: p.join(articleDir, contentPath),
      coverImageUrl: coverImageUrl,
      coverImagePath: coverImagePath != null
          ? p.join(articleDir, coverImagePath!)
          : null,
      textLength: textLength,
      estimatedWordCount: estimatedWordCount,
      currentScrollOffset: currentScrollOffset,
      addedAt: DateTime.tryParse(addedAt) ?? _epoch,
      lastOpenedAt: lastOpenedAt != null
          ? DateTime.tryParse(lastOpenedAt!)
          : null,
      isFinished: isFinished,
    );
  }
}
