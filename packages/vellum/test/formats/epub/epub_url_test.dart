import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

void main() {
  group('resolveEpubUrl', () {
    test('resolves against the package document directory', () {
      expect(
        resolveEpubUrl('text/ch1.xhtml', 'OEBPS/content.opf'),
        'OEBPS/text/ch1.xhtml',
      );
      expect(
        resolveEpubUrl('../images/a.png', 'OEBPS/text/ch1.xhtml'),
        'OEBPS/images/a.png',
      );
      expect(resolveEpubUrl('ch1.xhtml', 'content.opf'), 'ch1.xhtml');
      expect(
        resolveEpubUrl('/abs/x.xhtml', 'OEBPS/content.opf'),
        'abs/x.xhtml',
      );
    });

    test('decodes escapes, keeps reserved ones, drops the query', () {
      expect(
        resolveEpubUrl('chapter%201.xhtml', 'OEBPS/content.opf'),
        'OEBPS/chapter 1.xhtml',
      );
      expect(
        resolveEpubUrl('ch%2C1.html', 'OPS/book.opf'),
        'OPS/ch,1.html',
        reason: 'calibre encodes commas it means raw',
      );
      expect(resolveEpubUrl('a%3Ab.xhtml', 'x.opf'), 'a:b.xhtml');
      expect(resolveEpubUrl('ch1.xhtml?x=1#frag', 'x.opf'), 'ch1.xhtml#frag');
      expect(
        resolveEpubUrl('%D0%BA%D0%BD%D0%B8%D0%B3%D0%B0.xhtml', 'x.opf'),
        'книга.xhtml',
      );
    });

    test('an absolute URL or an absolute base resolves as a URL', () {
      expect(
        resolveEpubUrl('https://example.com/a', 'OEBPS/content.opf'),
        'https://example.com/a',
      );
      expect(
        resolveEpubUrl('b.css', 'https://example.com/dir/a.xhtml'),
        'https://example.com/dir/b.css',
      );
      expect(resolveEpubUrl('b.css', 'OEBPS:odd/a.xhtml'), 'OEBPS:odd/b.css');
    });

    test('isExternalEpubUri sees schemes but not blobs', () {
      expect(isExternalEpubUri('https://x'), isTrue);
      expect(isExternalEpubUri('mailto:a@b'), isTrue);
      expect(isExternalEpubUri('blob:https://x'), isFalse);
      expect(isExternalEpubUri('text/ch1.xhtml'), isFalse);
      expect(isExternalEpubUri('#frag'), isFalse);
    });
  });

  group('decodeEpubUri', () {
    test('matches decodeURI: reserved characters stay encoded', () {
      expect(decodeEpubUri('a%20b'), 'a b');
      expect(decodeEpubUri('a%2Cb'), 'a%2Cb');
      expect(decodeEpubUri('a%2Fb%3Fc%23d'), 'a%2Fb%3Fc%23d');
      expect(decodeEpubUri('%D0%96'), 'Ж');
      expect(decodeEpubUri('100%'), '100%');
      expect(decodeEpubUri('%zz'), '%zz');
      expect(decodeEpubUri('plain'), 'plain');
    });
  });

  group('paths', () {
    test('dirname and relative paths', () {
      expect(epubPathDirname('OEBPS/text/a.xhtml'), 'OEBPS/text/');
      expect(epubPathDirname('a.xhtml'), '');
      expect(epubPathRelative('', 'a/b'), 'a/b');
      expect(epubPathRelative('a/b', 'a/c'), '../c');
      expect(epubPathRelative('a/b/', 'a/b'), '');
      expect(epubPathRelative('a', 'a/b/c'), 'b/c');
      expect(epubPathRelative('x/y/z', 'x/w'), '../../w');
    });
  });
}
