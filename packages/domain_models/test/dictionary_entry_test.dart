import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  DictionaryEntry entry() => DictionaryEntry(
    id: 'e1',
    word: 'hello',
    translation: 'привет',
    addedAt: now,
  );

  group('DictionaryEntry copyWith()', () {
    test('preserves id and addedAt', () {
      final e = entry().copyWith(word: 'hi');
      expect(e.id, 'e1');
      expect(e.addedAt, now);
      expect(e.word, 'hi');
    });

    test('updates translation', () {
      final e = entry().copyWith(translation: 'updated');
      expect(e.translation, 'updated');
    });

    test('updates usageExamples', () {
      final e = entry().copyWith(usageExamples: ['Hello world']);
      expect(e.usageExamples, ['Hello world']);
    });

    test('clears context when null is passed explicitly', () {
      final e = DictionaryEntry(
        id: 'e1',
        word: 'w',
        translation: 't',
        context: 'ctx',
        addedAt: now,
      ).copyWith(context: null);
      expect(e.context, isNull);
    });

    test('preserves context when not passed', () {
      final e = DictionaryEntry(
        id: 'e1',
        word: 'w',
        translation: 't',
        context: 'keep',
        addedAt: now,
      ).copyWith(word: 'changed');
      expect(e.context, 'keep');
    });
  });

  group('DictionaryEntry equality', () {
    test('same fields are equal', () {
      expect(entry(), equals(entry()));
    });

    test('different word are not equal', () {
      expect(entry(), isNot(equals(entry().copyWith(word: 'bye'))));
    });
  });
}
