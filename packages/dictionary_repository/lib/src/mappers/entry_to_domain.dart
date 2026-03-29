import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

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
    fsrs: FsrsCardData(
      state: FsrsState.from(fsrsState),
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      reps: reps,
      lapses: lapses,
      lastReviewAt: lastReviewAt != null ? DateTime.parse(lastReviewAt!) : null,
      nextReviewAt: nextReviewAt != null ? DateTime.parse(nextReviewAt!) : null,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
    ),
  );
}
