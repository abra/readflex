import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

extension ArticleToDomain on ArticlesTableData {
  Article toDomainModel() => Article(
    id: id,
    title: title,
    siteName: siteName,
    byline: byline,
    excerpt: excerpt,
    publishedTime: publishedTime,
    lang: lang,
    url: url,
    cleanedHtml: cleanedHtml,
    coverImageUrl: coverImageUrl,
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
