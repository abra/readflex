import 'package:shared/shared.dart';
import 'package:test/test.dart';

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
