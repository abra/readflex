import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension EntryToStorage on DictionaryEntry {
  DictionaryTableCompanion toStorageModel() => DictionaryTableCompanion(
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
    fsrsState: Value(fsrs.state.toStorageString()),
    stability: Value(fsrs.stability),
    difficulty: Value(fsrs.difficulty),
    retrievability: Value(fsrs.retrievability),
    reps: Value(fsrs.reps),
    lapses: Value(fsrs.lapses),
    lastReviewAt: Value(fsrs.lastReviewAt?.toIso8601String()),
    nextReviewAt: Value(fsrs.nextReviewAt?.toIso8601String()),
    scheduledDays: Value(fsrs.scheduledDays),
    elapsedDays: Value(fsrs.elapsedDays),
  );
}
