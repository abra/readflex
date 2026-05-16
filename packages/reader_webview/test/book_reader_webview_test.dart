import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('resolveInitialReaderLocation', () {
    test('prefers exact CFI on normal load', () {
      final location = resolveInitialReaderLocation(
        initialCfi: 'epubcfi(/6/14!/4/2)',
        initialProgress: 0.73,
        recoveringFromCrash: false,
      );

      expect(location.cfi, 'epubcfi(/6/14!/4/2)');
      expect(location.progress, isNull);
    });

    test('falls back to progress when CFI is missing', () {
      final location = resolveInitialReaderLocation(
        initialCfi: null,
        initialProgress: 0.73,
        recoveringFromCrash: false,
      );

      expect(location.cfi, isNull);
      expect(location.progress, 0.73);
    });

    test('drops CFI during recovery but keeps progress fallback', () {
      final location = resolveInitialReaderLocation(
        initialCfi: 'epubcfi(/6/14!/4/2)',
        initialProgress: 0.73,
        recoveringFromCrash: true,
      );

      expect(location.cfi, isNull);
      expect(location.progress, 0.73);
    });

    test('rejects non-positive progress fallback', () {
      final location = resolveInitialReaderLocation(
        initialCfi: null,
        initialProgress: 0,
        recoveringFromCrash: false,
      );

      expect(location.cfi, isNull);
      expect(location.progress, isNull);
    });
  });

  group('foliate bootstrap', () {
    test('always uses the modern app bridge', () {
      final indexHtml = File(
        'assets/foliate-js/index.html',
      ).readAsStringSync();
      final bookJs = File(
        'assets/foliate-js/src/book.js',
      ).readAsStringSync();

      expect(indexHtml, isNot(contains('shouldUseModernBundle')));
      expect(indexHtml, isNot(contains('./dist/bundle.js')));
      expect(indexHtml, isNot(contains('./dist/pdf-legacy.js')));
      expect(indexHtml, contains("await loadScript('./src/book.js'"));
      expect(
        indexHtml,
        contains("await loadScript('./src/vendor/pdfjs/pdf.js'"),
      );
      expect(bookJs, contains('window.startSearch'));
      expect(bookJs, contains('window.cancelSearch'));
      expect(bookJs, contains("callFlutter('onSearch'"));
    });

    test('keeps default search off Intl Segmenter', () {
      final searchJs = File(
        'assets/foliate-js/src/search.js',
      ).readAsStringSync();

      expect(searchJs, contains("granularity !== 'word'"));
      expect(searchJs, contains('return simpleSearch(strs, query, options)'));
    });

    test('applies reader background color inside the iframe document', () {
      final bookJs = File(
        'assets/foliate-js/src/book.js',
      ).readAsStringSync();

      expect(
        bookJs,
        contains('--readflex-background-color: \${backgroundColor};'),
      );
      expect(
        bookJs,
        contains('--readflex-prose-font-size: \${proseFontSizePx}px;'),
      );
      expect(
        bookJs,
        contains(
          '--readflex-code-block-font-size: \${codeBlockFontSizePx}px;',
        ),
      );
      expect(bookJs, contains('textScale: style.textScale'));
      expect(bookJs, isNot(contains('const layoutChanged =')));
      expect(bookJs, isNot(contains('oldStyle?.fontSize !== style.fontSize')));
      expect(
        bookJs,
        contains(
          'background-color: var(--readflex-background-color) !important;',
        ),
      );
      expect(
        bookJs,
        isNot(contains('background-color: transparent !important;')),
      );
    });

    test('guards pagination while iframe document body is unavailable', () {
      final paginatorJs = File(
        'assets/foliate-js/src/paginator.js',
      ).readAsStringSync();

      expect(paginatorJs, contains('if (!doc?.body)'));
      expect(
        paginatorJs,
        contains('[readflex-paginator] visible range skipped'),
      );
      expect(paginatorJs, contains('if (!range) return'));
    });
  });

  group('search bridge script', () {
    test('guards missing startSearch and escapes query', () {
      final script = buildReaderSearchStartScript(
        requestId: 42,
        query: 'email "test"',
      );

      expect(script, contains('const requestId = 42;'));
      expect(script, contains('const query = "email \\"test\\"";'));
      expect(script, contains("typeof window.startSearch !== 'function'"));
      expect(script, isNot(contains('window.search')));
      expect(script, contains("bridge.callHandler('onSearch'"));
      expect(script, contains('Book search bridge is missing'));
      expect(script, contains("type: 'error'"));
    });
  });

  group('console logging', () {
    test('keeps warning noise out of release logs', () {
      expect(
        shouldLogReaderConsoleMessage(
          debugMode: false,
          level: 'WARNING',
        ),
        isFalse,
      );
      expect(
        shouldLogReaderConsoleMessage(debugMode: false, level: 'ERROR'),
        isTrue,
      );
      expect(
        shouldLogReaderConsoleMessage(
          debugMode: true,
          level: 'WARNING',
        ),
        isTrue,
      );
    });
  });

  group('asset extraction', () {
    test('versions bundled reader assets independently of app version', () {
      expect(
        AssetExtractor.extractionVersionFor('1.0.0+1'),
        '1.0.0+1|${AssetExtractor.assetRevision}',
      );
    });
  });
}
