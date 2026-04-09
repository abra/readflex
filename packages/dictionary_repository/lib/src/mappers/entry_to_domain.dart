import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

extension EntryToDomain on DictionaryTableData {
  DictionaryEntry toDomainModel() => DictionaryEntry(
    id: id,
    word: word,
    translation: translation,
    pronunciation: pronunciation,
    partOfSpeech: partOfSpeech,
    context: this.context,
    sourceId: sourceId,
    sourceType: sourceType != null ? SourceType.from(sourceType!) : null,
    usageExamples: usageExamples != null
        ? (jsonDecode(usageExamples!) as List).cast<String>()
        : const [],
    addedAt: DateTime.tryParse(addedAt) ?? _epoch,
  );
}
