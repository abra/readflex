import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookFormat.from()', () {
    test('returns correct value for each known string', () {
      expect(BookFormat.from('epub'), BookFormat.epub);
      expect(BookFormat.from('fb2'), BookFormat.fb2);
      expect(BookFormat.from('mobi'), BookFormat.mobi);
      expect(BookFormat.from('pdf'), BookFormat.pdf);
      expect(BookFormat.from('azw3'), BookFormat.azw3);
      expect(BookFormat.from('cbz'), BookFormat.cbz);
    });

    test('returns epub for unsupported strings', () {
      // Unsupported values fall back to epub for existing persisted rows.
      expect(BookFormat.from('txt'), BookFormat.epub);
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
      expect(BookFormat.fromExtension('.azw3'), BookFormat.azw3);
      expect(BookFormat.fromExtension('.cbz'), BookFormat.cbz);
    });

    test('returns null for unsupported extensions like .txt', () {
      expect(BookFormat.fromExtension('.txt'), isNull);
    });

    test('is case-insensitive', () {
      expect(BookFormat.fromExtension('.EPUB'), BookFormat.epub);
      expect(BookFormat.fromExtension('.Pdf'), BookFormat.pdf);
    });

    test('returns null for unknown extension', () {
      expect(BookFormat.fromExtension('.doc'), isNull);
      expect(BookFormat.fromExtension('.rtf'), isNull);
    });
  });
}
