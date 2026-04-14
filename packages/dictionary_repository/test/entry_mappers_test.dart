import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

import 'package:dictionary_repository/src/mappers/entry_to_domain.dart';
import 'package:dictionary_repository/src/mappers/entry_to_storage.dart';

void main() {
  final now = DateTime(2026, 4, 1);

  group('EntryToDomain', () {
    test('maps all fields from storage to domain', () {
      final row = DictionaryTableData(
        id: 'd1',
        word: 'hello',
        translation: 'привет',
        pronunciation: 'hɛˈloʊ',
        partOfSpeech: 'interjection',
        context: 'greeting',
        sourceId: 'book-1',
        sourceType: 'book',
        usageExamples: jsonEncode(['Hello there', 'Say hello']),
        addedAt: now.toIso8601String(),
      );

      final entry = row.toDomainModel();

      expect(entry.id, 'd1');
      expect(entry.word, 'hello');
      expect(entry.translation, 'привет');
      expect(entry.pronunciation, 'hɛˈloʊ');
      expect(entry.partOfSpeech, 'interjection');
      expect(entry.context, 'greeting');
      expect(entry.sourceId, 'book-1');
      expect(entry.sourceType, SourceType.book);
      expect(entry.usageExamples, ['Hello there', 'Say hello']);
      expect(entry.addedAt, now);
    });

    test('handles null optional fields', () {
      final row = DictionaryTableData(
        id: 'd2',
        word: 'test',
        translation: 'тест',
        pronunciation: null,
        partOfSpeech: null,
        context: null,
        sourceId: null,
        sourceType: null,
        usageExamples: null,
        addedAt: now.toIso8601String(),
      );

      final entry = row.toDomainModel();

      expect(entry.pronunciation, isNull);
      expect(entry.partOfSpeech, isNull);
      expect(entry.context, isNull);
      expect(entry.sourceId, isNull);
      expect(entry.sourceType, isNull);
      expect(entry.usageExamples, isEmpty);
    });

    test('falls back to epoch for invalid date', () {
      final row = DictionaryTableData(
        id: 'd3',
        word: 'w',
        translation: 't',
        pronunciation: null,
        partOfSpeech: null,
        context: null,
        sourceId: null,
        sourceType: null,
        usageExamples: null,
        addedAt: 'bad',
      );

      expect(
        row.toDomainModel().addedAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  });

  group('EntryToStorage', () {
    test('maps all fields from domain to companion', () {
      final entry = DictionaryEntry(
        id: 'd1',
        word: 'hello',
        translation: 'привет',
        pronunciation: 'hɛˈloʊ',
        partOfSpeech: 'interjection',
        context: 'greeting',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        usageExamples: const ['Hello there', 'Say hello'],
        addedAt: now,
      );

      final companion = entry.toStorageModel();

      expect(companion.id, const Value('d1'));
      expect(companion.word, const Value('hello'));
      expect(companion.translation, const Value('привет'));
      expect(companion.pronunciation, const Value('hɛˈloʊ'));
      expect(companion.sourceType, const Value('book'));
      expect(
        companion.usageExamples,
        Value(jsonEncode(['Hello there', 'Say hello'])),
      );
    });

    test('encodes empty examples as null', () {
      final entry = DictionaryEntry(
        id: 'd1',
        word: 'w',
        translation: 't',
        addedAt: now,
      );

      final companion = entry.toStorageModel();

      expect(companion.usageExamples, const Value(null));
    });

    test('round-trips through domain and back', () {
      final original = DictionaryEntry(
        id: 'd1',
        word: 'hello',
        translation: 'привет',
        sourceType: SourceType.book,
        usageExamples: const ['Example'],
        addedAt: now,
      );

      final companion = original.toStorageModel();
      final row = DictionaryTableData(
        id: companion.id.value,
        word: companion.word.value,
        translation: companion.translation.value,
        pronunciation: companion.pronunciation.value,
        partOfSpeech: companion.partOfSpeech.value,
        context: companion.context.value,
        sourceId: companion.sourceId.value,
        sourceType: companion.sourceType.value,
        usageExamples: companion.usageExamples.value,
        addedAt: companion.addedAt.value,
      );
      final restored = row.toDomainModel();

      expect(restored, equals(original));
    });
  });
}
