import 'dart:convert';

import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

extension EntryToDomain on DictionaryEntriesTableData {
  DictionaryEntry toDomainModel() => DictionaryEntry(
    id: id,
    word: word,
    translation: translation,
    context: this.context,
    sourceId: sourceId,
    sourceType: sourceType != null ? SourceType.from(sourceType!) : null,
    usageExamples: usageExamples != null
        ? (jsonDecode(usageExamples!) as List).cast<String>()
        : const [],
    addedAt: DateTime.parse(addedAt),
  );
}
