import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Highlight highlight() => Highlight(
    id: 'h1',
    sourceId: 's1',
    sourceType: SourceType.book,
    text: 'Some text',
    createdAt: now,
  );

  group('Highlight copyWith()', () {
    test('preserves id and createdAt', () {
      final h = highlight().copyWith(text: 'New text');
      expect(h.id, 'h1');
      expect(h.createdAt, now);
      expect(h.text, 'New text');
    });

    test('updates note', () {
      final h = highlight().copyWith(note: 'My note');
      expect(h.note, 'My note');
    });

    test('clears note when null is passed explicitly', () {
      final h = Highlight(
        id: 'h1',
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'text',
        note: 'existing',
        createdAt: now,
      ).copyWith(note: null);
      expect(h.note, isNull);
    });

    test('preserves note when not passed', () {
      final h = Highlight(
        id: 'h1',
        sourceId: 's1',
        sourceType: SourceType.book,
        text: 'text',
        note: 'keep',
        createdAt: now,
      ).copyWith(text: 'changed');
      expect(h.note, 'keep');
    });

    test('updates color', () {
      final h = highlight().copyWith(color: HighlightColor.blue);
      expect(h.color, HighlightColor.blue);
    });
  });

  group('Highlight equality', () {
    test('same fields are equal', () {
      expect(highlight(), equals(highlight()));
    });

    test('different text are not equal', () {
      expect(highlight(), isNot(equals(highlight().copyWith(text: 'other'))));
    });
  });

  group('HighlightColor.from()', () {
    test('returns correct value', () {
      expect(HighlightColor.from('blue'), HighlightColor.blue);
      expect(HighlightColor.from('pink'), HighlightColor.pink);
    });

    test('returns yellow for unknown', () {
      expect(HighlightColor.from('unknown'), HighlightColor.yellow);
    });
  });
}
