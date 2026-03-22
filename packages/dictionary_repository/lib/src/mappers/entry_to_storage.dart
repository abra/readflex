import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

extension EntryToStorage on DictionaryEntry {
  DictionaryEntriesTableCompanion toStorageModel() =>
      DictionaryEntriesTableCompanion(
        id: Value(id),
        word: Value(word),
        translation: Value(translation),
        context: Value(context),
        sourceId: Value(sourceId),
        sourceType: Value(sourceType?.name),
        usageExamples: Value(
          usageExamples.isEmpty ? null : jsonEncode(usageExamples),
        ),
        addedAt: Value(addedAt.toIso8601String()),
      );
}
