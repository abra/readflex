import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

extension ArticleToDomain on ArticlesTableData {
  Article toDomainModel() => Article(
    id: id,
    title: title,
    siteName: siteName,
    url: url,
    cleanedHtml: cleanedHtml,
    coverImageUrl: coverImageUrl,
    estimatedWordCount: estimatedWordCount,
    currentScrollOffset: currentScrollOffset,
    addedAt: DateTime.parse(addedAt),
    lastOpenedAt: lastOpenedAt != null ? DateTime.parse(lastOpenedAt!) : null,
    isFinished: isFinished,
  );
}
