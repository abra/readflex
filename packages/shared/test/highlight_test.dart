import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Highlight _highlight() => Highlight(
    id: 'h1',
    sourceId: 's1',
    sourceType: SourceType.book,
    text: 'Some text',
    createdAt: now,
  );

  group('Highlight copyWith()', () {
    test('preserves id and createdAt', () {
      final h = _highlight().copyWith(text: 'New text');
      expect(h.id, 'h1');
      expect(h.createdAt, now);
      expect(h.text, 'New text');
    });

    test('updates note', () {
      final h = _highlight().copyWith(note: 'My note');
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
      final h = _highlight().copyWith(color: HighlightColor.blue);
      expect(h.color, HighlightColor.blue);
    });
  });

  group('Highlight equality', () {
    test('same fields are equal', () {
      expect(_highlight(), equals(_highlight()));
    });

    test('different text are not equal', () {
      expect(_highlight(), isNot(equals(_highlight().copyWith(text: 'other'))));
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
