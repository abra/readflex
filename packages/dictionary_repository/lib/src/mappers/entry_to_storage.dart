import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension EntryToStorage on DictionaryEntry {
  DictionaryTableCompanion toStorageModel() => DictionaryTableCompanion(
    id: Value(id),
    word: Value(word),
    translation: Value(translation),
    pronunciation: Value(pronunciation),
    partOfSpeech: Value(partOfSpeech),
    context: Value(context),
    sourceId: Value(sourceId),
    sourceType: Value(sourceType?.name),
    usageExamples: Value(
      usageExamples.isEmpty ? null : jsonEncode(usageExamples),
    ),
    addedAt: Value(addedAt.toIso8601String()),
  );
}
