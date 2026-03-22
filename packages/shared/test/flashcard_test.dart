import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Flashcard _card() => Flashcard(
    id: 'f1',
    deckId: 'd1',
    front: 'Front',
    back: 'Back',
    createdAt: now,
  );

  group('Flashcard copyWith()', () {
    test('preserves id and createdAt', () {
      final c = _card().copyWith(front: 'New front');
      expect(c.id, 'f1');
      expect(c.createdAt, now);
      expect(c.front, 'New front');
    });

    test('updates hint', () {
      final c = _card().copyWith(hint: 'A hint');
      expect(c.hint, 'A hint');
    });

    test('clears hint when null is passed explicitly', () {
      final c = Flashcard(
        id: 'f1',
        deckId: 'd1',
        front: 'F',
        back: 'B',
        hint: 'existing',
        createdAt: now,
      ).copyWith(hint: null);
      expect(c.hint, isNull);
    });

    test('updates fsrs data', () {
      final c = _card().copyWith(
        fsrs: const FsrsCardData(
          state: FsrsState.review,
          stability: 5.0,
          difficulty: 3.0,
        ),
      );
      expect(c.fsrs.state, FsrsState.review);
      expect(c.fsrs.stability, 5.0);
    });
  });

  group('Flashcard equality', () {
    test('same fields are equal', () {
      expect(_card(), equals(_card()));
    });

    test('different front are not equal', () {
      expect(_card(), isNot(equals(_card().copyWith(front: 'other'))));
    });
  });

  group('FsrsState', () {
    test('from() parses known values', () {
      expect(FsrsState.from('new'), FsrsState.newCard);
      expect(FsrsState.from('learning'), FsrsState.learning);
      expect(FsrsState.from('review'), FsrsState.review);
      expect(FsrsState.from('relearning'), FsrsState.relearning);
    });

    test('from() returns newCard for unknown', () {
      expect(FsrsState.from('unknown'), FsrsState.newCard);
    });

    test('toStorageString() round-trips', () {
      for (final state in FsrsState.values) {
        expect(FsrsState.from(state.toStorageString()), state);
      }
    });
  });

  group('CreationSource.from()', () {
    test('returns correct value', () {
      expect(CreationSource.from('manual'), CreationSource.manual);
      expect(CreationSource.from('aiHighlight'), CreationSource.aiHighlight);
    });

    test('returns manual for unknown', () {
      expect(CreationSource.from('unknown'), CreationSource.manual);
    });
  });

  group('Rating.from()', () {
    test('returns correct value', () {
      expect(Rating.from('again'), Rating.again);
      expect(Rating.from('easy'), Rating.easy);
    });

    test('returns again for unknown', () {
      expect(Rating.from('unknown'), Rating.again);
    });
  });
}
