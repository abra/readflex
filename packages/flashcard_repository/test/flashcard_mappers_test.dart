import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flashcard_repository/src/mappers/flashcard_to_domain.dart';
import 'package:flashcard_repository/src/mappers/flashcard_to_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  final now = DateTime(2026, 4, 1);

  group('FlashcardToDomain', () {
    test('maps all fields from storage to domain', () {
      final row = FlashcardsTableData(
        id: 'f1',
        deckId: 'd1',
        front: 'Front',
        back: 'Back',
        hint: 'A hint',
        sourceHighlightId: 'h1',
        creationSource: 'aiHighlight',
        createdAt: now.toIso8601String(),
      );

      final card = row.toDomainModel();

      expect(card.id, 'f1');
      expect(card.deckId, 'd1');
      expect(card.front, 'Front');
      expect(card.back, 'Back');
      expect(card.hint, 'A hint');
      expect(card.sourceHighlightId, 'h1');
      expect(card.creationSource, CreationSource.aiHighlight);
      expect(card.createdAt, now);
    });

    test('handles null optional fields', () {
      final row = FlashcardsTableData(
        id: 'f2',
        deckId: 'd1',
        front: 'F',
        back: 'B',
        hint: null,
        sourceHighlightId: null,
        creationSource: 'manual',
        createdAt: now.toIso8601String(),
      );

      final card = row.toDomainModel();

      expect(card.hint, isNull);
      expect(card.sourceHighlightId, isNull);
      expect(card.creationSource, CreationSource.manual);
    });

    test('falls back to epoch for invalid date', () {
      final row = FlashcardsTableData(
        id: 'f3',
        deckId: 'd1',
        front: 'F',
        back: 'B',
        hint: null,
        sourceHighlightId: null,
        creationSource: 'manual',
        createdAt: 'not-a-date',
      );

      final card = row.toDomainModel();

      expect(card.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('FlashcardToStorage', () {
    test('maps all fields from domain to companion', () {
      final card = Flashcard(
        id: 'f1',
        deckId: 'd1',
        front: 'Front',
        back: 'Back',
        hint: 'A hint',
        sourceHighlightId: 'h1',
        creationSource: CreationSource.aiHighlight,
        createdAt: now,
      );

      final companion = card.toStorageModel();

      expect(companion.id, const Value('f1'));
      expect(companion.deckId, const Value('d1'));
      expect(companion.front, const Value('Front'));
      expect(companion.back, const Value('Back'));
      expect(companion.hint, const Value('A hint'));
      expect(companion.sourceHighlightId, const Value('h1'));
      expect(companion.creationSource, const Value('aiHighlight'));
      expect(companion.createdAt, Value(now.toIso8601String()));
    });

    test('round-trips through domain and back', () {
      final original = Flashcard(
        id: 'f1',
        deckId: 'd1',
        front: 'Front',
        back: 'Back',
        createdAt: now,
      );

      final companion = original.toStorageModel();
      final row = FlashcardsTableData(
        id: companion.id.value,
        deckId: companion.deckId.value,
        front: companion.front.value,
        back: companion.back.value,
        hint: companion.hint.value,
        sourceHighlightId: companion.sourceHighlightId.value,
        creationSource: companion.creationSource.value,
        createdAt: companion.createdAt.value,
      );
      final restored = row.toDomainModel();

      expect(restored, equals(original));
    });
  });
}
