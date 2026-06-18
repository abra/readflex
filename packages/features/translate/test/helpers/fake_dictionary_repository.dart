import 'dart:async';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  /// When set, `addEntry` blocks on this completer's future before
  /// resolving. Tests that need to simulate "user dismissed mid-save"
  /// complete it after closing the cubit.
  Completer<void>? awaitGate;

  final List<DictionaryEntry> entries = [];
  final List<DictionaryAnchor> anchors = [];

  @override
  Future<DictionaryEntry> addEntry({
    required String word,
    required String translation,
    String? pronunciation,
    String? partOfSpeech,
    String? context,
    String? sourceId,
    SourceType? sourceType,
    List<String> usageExamples = const [],
    DateTime? addedAt,
    String? anchorText,
    String? anchorContext,
    String? anchorCfiRange,
    DictionaryAnchorKind? anchorKind,
  }) async {
    if (awaitGate != null) await awaitGate!.future;
    if (shouldThrow) throw Exception('addEntry failed');

    final entry = DictionaryEntry(
      id: 'de-${entries.length + 1}',
      word: word,
      translation: translation,
      pronunciation: pronunciation,
      partOfSpeech: partOfSpeech,
      context: context,
      sourceId: sourceId,
      sourceType: sourceType,
      usageExamples: usageExamples,
      addedAt: addedAt ?? DateTime.now(),
    );
    entries.add(entry);
    if (sourceId != null &&
        sourceType != null &&
        anchorText != null &&
        anchorCfiRange != null) {
      anchors.add(
        DictionaryAnchor(
          id: 'da-${anchors.length + 1}',
          entryId: entry.id,
          sourceId: sourceId,
          sourceType: sourceType,
          text: anchorText,
          context: anchorContext,
          cfiRange: anchorCfiRange,
          kind: anchorKind ?? DictionaryAnchorKind.exactSelection,
          createdAt: addedAt ?? DateTime.now(),
        ),
      );
    }
    return entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    if (shouldThrow) throw Exception('deleteEntry failed');
    entries.removeWhere((entry) => entry.id == id);
    anchors.removeWhere((anchor) => anchor.entryId == id);
  }
}
