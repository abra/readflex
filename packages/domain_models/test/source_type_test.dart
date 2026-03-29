import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceType.from()', () {
    test('returns correct value for known strings', () {
      expect(SourceType.from('book'), SourceType.book);
      expect(SourceType.from('article'), SourceType.article);
    });

    test('returns book for unknown string', () {
      expect(SourceType.from('unknown'), SourceType.book);
    });

    test('returns book for null', () {
      expect(SourceType.from(null), SourceType.book);
    });
  });
}
