import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReviewableType.from()', () {
    test('parses known values', () {
      expect(ReviewableType.from('flashcard'), ReviewableType.flashcard);
      expect(ReviewableType.from('highlight'), ReviewableType.highlight);
      expect(ReviewableType.from('dictionary'), ReviewableType.dictionary);
    });

    test('returns flashcard for unknown', () {
      expect(ReviewableType.from('unknown'), ReviewableType.flashcard);
    });
  });

  group('ReviewableType.toStorageString()', () {
    test('round-trips through from()', () {
      for (final type in ReviewableType.values) {
        expect(ReviewableType.from(type.toStorageString()), type);
      }
    });
  });
}
