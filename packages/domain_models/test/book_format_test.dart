import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookFormat.from()', () {
    test('returns correct value for each known string', () {
      expect(BookFormat.from('epub'), BookFormat.epub);
      expect(BookFormat.from('fb2'), BookFormat.fb2);
      expect(BookFormat.from('mobi'), BookFormat.mobi);
      expect(BookFormat.from('pdf'), BookFormat.pdf);
    });

    test('returns epub for unknown string', () {
      expect(BookFormat.from('unknown'), BookFormat.epub);
    });

    test('returns epub for null', () {
      expect(BookFormat.from(null), BookFormat.epub);
    });
  });

  group('BookFormat.fromExtension()', () {
    test('returns correct format for known extensions', () {
      expect(BookFormat.fromExtension('.epub'), BookFormat.epub);
      expect(BookFormat.fromExtension('.fb2'), BookFormat.fb2);
      expect(BookFormat.fromExtension('.mobi'), BookFormat.mobi);
      expect(BookFormat.fromExtension('.pdf'), BookFormat.pdf);
    });

    test('is case-insensitive', () {
      expect(BookFormat.fromExtension('.EPUB'), BookFormat.epub);
      expect(BookFormat.fromExtension('.Pdf'), BookFormat.pdf);
    });

    test('returns null for unknown extension', () {
      expect(BookFormat.fromExtension('.txt'), isNull);
      expect(BookFormat.fromExtension('.doc'), isNull);
    });
  });
}
