import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

extension ArticleToDomain on ArticlesTableData {
  Article toDomainModel({required Directory articlesDir}) {
    final articleDir = p.join(articlesDir.path, id);
    return Article(
      id: id,
      title: title,
      url: url,
      resolvedUrl: resolvedUrl,
      canonicalUrl: canonicalUrl,
      author: author,
      siteName: siteName,
      hostname: hostname,
      description: description,
      imageUrl: imageUrl,
      coverImagePath: coverImagePath != null
          ? p.join(articleDir, coverImagePath!)
          : null,
      language: language,
      contentPath: p.join(articleDir, contentPath),
      plainText: plainText,
      textLength: textLength,
      estimatedWordCount: estimatedWordCount,
      currentCfi: currentCfi,
      readingProgress: readingProgress,
      addedAt: DateTime.tryParse(addedAt) ?? _epoch,
      lastOpenedAt: lastOpenedAt != null
          ? DateTime.tryParse(lastOpenedAt!)
          : null,
      isFinished: isFinished,
    );
  }
}
