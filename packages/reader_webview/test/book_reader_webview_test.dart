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

  group('article source detection', () {
    test('recognizes generated article epub paths', () {
      expect(
        isGeneratedArticleReaderPath('/app/Documents/articles/id/article.epub'),
        isTrue,
      );
      expect(
        isGeneratedArticleReaderPath('/app/Documents/books/id/book.epub'),
        isFalse,
      );
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
      expect(bookJs, contains('window.goToBookmark'));
      expect(bookJs, contains('window.toggleBookmarkHere'));
      expect(bookJs, contains('globalThis.readflexSourceType = sourceType'));
      expect(bookJs, contains('normalizeLoadedDocument(doc)'));
      expect(bookJs, contains("callFlutter('onSearch'"));
      expect(bookJs, contains("callFlutter('handleBookmark'"));
    });

    test('pull-down bookmark does not render transient feedback icon', () {
      final bookJs = File(
        'assets/foliate-js/src/book.js',
      ).readAsStringSync();

      expect(bookJs, isNot(contains('bookmark-feedback-icon')));
      expect(bookJs, isNot(contains('showBookmarkFeedback')));
      expect(bookJs, isNot(contains('fill="#215a8f"')));
    });

    test('bookmark state is refreshed after stored annotations render', () {
      final bookJs = File(
        'assets/foliate-js/src/book.js',
      ).readAsStringSync();
      final viewJs = File(
        'assets/foliate-js/src/view.js',
      ).readAsStringSync();
      final webViewDart = File(
        'lib/src/book_reader_webview.dart',
      ).readAsStringSync();

      expect(bookJs, contains('window.refreshBookmarkState'));
      expect(bookJs, contains("reason = 'bookmark-sync'"));
      expect(bookJs, isNot(contains('#rangeContainsBookmark')));
      expect(bookJs, isNot(contains('currentRange.comparePoint')));
      expect(bookJs, isNot(contains('resolveCFI(bookmark.value)')));
      expect(bookJs, contains('#checkBookmark(bm, currentAnchor)'));
      expect(
        bookJs,
        contains('#sameBookmarkTextAnchor(bookmark, currentAnchor)'),
      );
      expect(
        bookJs,
        contains('#sameBookmarkVisualPageAnchor(bookmark, currentAnchor)'),
      );
      expect(bookJs, contains('#isBookmarkAnchorInteger(value)'));
      expect(bookJs, contains("value != null && value !== ''"));
      expect(bookJs, contains('#rangeIsVisibleInViewport(range)'));
      expect(bookJs, contains('range.getClientRects()'));
      expect(bookJs, contains('unwrapCFI(cfi)'));
      expect(bookJs, contains('unwrapCFI(a)'));
      expect(bookJs, contains('#isPreciseBookmarkCfi(cfi)'));
      expect(bookJs, contains('#rangeLooksLikeBookmarkAnchor(range)'));
      expect(bookJs, contains('#bookmarkSelectorFromRange(anchorRange)'));
      expect(
        bookJs,
        contains('#bookmarkVisualPageAnchorFromLocation(location)'),
      );
      expect(bookJs, contains('anchorExact: anchor?.anchorExact'));
      expect(bookJs, contains('anchorSectionPage: anchor?.anchorSectionPage'));
      expect(webViewDart, contains("'anchorExact': bookmark.anchorExact"));
      expect(
        webViewDart,
        contains("'anchorSectionPage': bookmark.anchorSectionPage"),
      );
      expect(
        webViewDart,
        contains(r'removeAnnotation($escaped, false, $escapedId)'),
      );
      expect(bookJs, isNot(contains('#checkBookmarkProgress')));
      expect(bookJs, isNot(contains('anchor?.cfi ?? location?.cfi')));
      expect(bookJs, contains('#bookmarkAnchorFromLocation(location)'));
      expect(bookJs, contains('goToBookmark = async target'));
      expect(
        bookJs,
        contains('this.view.goToSectionPage(sectionIndex, sectionPage)'),
      );
      expect(bookJs, contains('#visibleViewportBookmarkRange(visibleRange)'));
      expect(bookJs, contains('#visibleViewportWordRange(visibleRange)'));
      expect(bookJs, contains('#nearestVisibleWordRange('));
      expect(bookJs, contains('#rangeViewportScore('));
      expect(bookJs, contains('caretRangeFromPoint'));
      expect(bookJs, contains('caretPositionFromPoint'));
      expect(bookJs, contains('this.view.getCFI(this.#index, anchorRange)'));
      expect(viewJs, isNot(contains("if (cfi && (!this.#lastCfi")));
      expect(viewJs, contains('#lastRelocateKey'));
      expect(viewJs, contains('async goToSectionPage(index, page)'));
      expect(
        viewJs,
        contains('this.history.pushState({ sectionIndex, sectionPage })'),
      );
      expect(viewJs, contains('currentPage ??'));
      expect(viewJs, contains('totalPages ??'));
      expect(webViewDart, contains("'progress': bookmark.progress"));
      expect(webViewDart, contains('window.refreshBookmarkState'));
      expect(
        webViewDart,
        contains("'sourceType': jsonEncode(_effectiveArticle"),
      );
    });

    test('bookmark drawer text comes from the visible page range', () {
      final bookJs = File(
        'assets/foliate-js/src/book.js',
      ).readAsStringSync();

      expect(
        bookJs,
        contains(
          'content: this.#bookmarkContentFromVisibleRange(visibleRange)',
        ),
      );
      expect(bookJs, contains('#bookmarkContentFromVisibleRange(range)'));
      expect(
        bookJs,
        isNot(contains('parentElement?.textContent')),
      );
    });

    test('keeps default search off Intl Segmenter', () {
      final searchJs = File(
        'assets/foliate-js/src/search.js',
      ).readAsStringSync();

      expect(searchJs, contains("granularity !== 'word'"));
      expect(searchJs, contains('return simpleSearch(strs, query, options)'));
    });

    test('resolves XHTML cover pages to their nested image', () {
      final epubJs = File(
        'assets/foliate-js/src/epub.js',
      ).readAsStringSync();

      expect(epubJs, contains('cover.mediaType === MIME.XHTML'));
      expect(epubJs, contains("doc.querySelector('img, image')"));
      expect(epubJs, contains("el?.getAttribute('src')"));
      expect(epubJs, contains("el?.getAttributeNS(NS.XLINK, 'href')"));
      expect(epubJs, contains('this.resources.getItemByHref(href)'));
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
        contains('--readflex-rtl-article-text-align: \${rtlArticleTextAlign};'),
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

    test('extracts and uses the document normalizer asset', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();
      final normalizerJs = File(
        'assets/foliate-js/src/readflex_document_normalizer.js',
      ).readAsStringSync();
      final assetExtractor = File(
        'lib/src/asset_extractor.dart',
      ).readAsStringSync();

      expect(
        bookJs,
        contains(
          "import { normalizeLoadedDocument } from './readflex_document_normalizer.js'",
        ),
      );
      expect(bookJs, contains('normalizeLoadedDocument(doc)'));
      expect(
        normalizerJs,
        contains('export const normalizeLoadedDocument = doc =>'),
      );
      expect(normalizerJs, contains('markInlineImages(doc)'));
      expect(normalizerJs, contains('wrapWideTables(doc)'));
      expect(normalizerJs, contains('normalizeCodeLikeBlocks(doc)'));
      expect(assetExtractor, contains('readflex_document_normalizer.js'));
      expect(assetExtractor, contains("reader_webview_assets_22"));
    });

    test('does not dump full reader style changes to console', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();

      expect(bookJs, isNot(contains("console.log('changeStyle'")));
      expect(bookJs, isNot(contains('JSON.stringify(style)')));
    });

    test('skips full CSS rebuild for margin-only style changes', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();

      expect(bookJs, contains('const readerCSSKeys = ['));
      expect(
        bookJs,
        contains(
          'const shouldUpdateReaderCSS = (oldStyle, nextStyle, flow) =>',
        ),
      );
      expect(
        bookJs,
        contains(
          "if ((oldStyle.pageTurnStyle === 'scroll') !== flow) return true",
        ),
      );
      expect(bookJs, contains('readerCSSKeys.some'));
      expect(
        bookJs,
        contains('const setRendererAttribute = (renderer, name, value) =>'),
      );
      expect(
        bookJs,
        contains('if (renderer.getAttribute(name) === nextValue) return'),
      );
      expect(bookJs, contains("setRendererAttribute(renderer, 'flow'"));
      expect(
        bookJs,
        contains('if (shouldUpdateReaderCSS(oldStyle, newStyle, turn.scroll))'),
      );
      expect(
        bookJs,
        contains('reader.view.renderer.setStyles?.(getCSS(newStyle))'),
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

    test('infers RTL direction when article language metadata is missing', () {
      final viewJs = File('assets/foliate-js/src/view.js').readAsStringSync();
      final normalizerJs = File(
        'assets/foliate-js/src/readflex_document_normalizer.js',
      ).readAsStringSync();
      final paginatorJs = File(
        'assets/foliate-js/src/paginator.js',
      ).readAsStringSync();

      expect(
        viewJs,
        contains(
          "import { languageInfo, normalizeDocumentLanguageAndDirection } from './readflex_document_normalizer.js'",
        ),
      );
      expect(viewJs, contains('normalizeDocumentLanguageAndDirection(doc, {'));
      expect(viewJs, contains('sourceType: globalThis.readflexSourceType'));
      expect(normalizerJs, contains('const rtlSampleRegex'));
      expect(
        normalizerJs,
        contains('export const inferDocumentDirection = doc =>'),
      );
      expect(normalizerJs, contains("rtlCount > ltrCount ? 'rtl' : ''"));
      expect(normalizerJs, contains('export const applyArticleTextDirection'));
      expect(
        normalizerJs,
        contains(
          'text-align: var(--readflex-rtl-article-text-align, right)',
        ),
      );
      expect(normalizerJs, contains("node.style.setProperty('direction'"));
      expect(normalizerJs, contains('doc.documentElement.dir = direction'));
      expect(normalizerJs, contains('if (doc.body) doc.body.dir = direction'));
      expect(normalizerJs, contains('doc.documentElement.dir ||= direction'));
      expect(
        normalizerJs,
        contains('if (doc.body) doc.body.dir ||= direction'),
      );
      expect(
        paginatorJs,
        isNot(contains('doc.documentElement.dataset.readflexTextDirection')),
      );
    });

    test('surfaces page progression direction to Dart', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();
      final viewJs = File('assets/foliate-js/src/view.js').readAsStringSync();
      final paginatorJs = File(
        'assets/foliate-js/src/paginator.js',
      ).readAsStringSync();
      final fixedLayoutJs = File(
        'assets/foliate-js/src/fixed-layout.js',
      ).readAsStringSync();
      final webViewDart = File(
        'lib/src/book_reader_webview.dart',
      ).readAsStringSync();

      expect(
        webViewDart,
        contains("'pageProgressionDirection': jsonEncode("),
      );
      expect(
        bookJs,
        contains('globalThis.readflexPageProgressionDirection'),
      );
      expect(
        bookJs,
        contains("pageProgressionDirection === 'rtl' ? 'rtl' : ''"),
      );
      expect(
        bookJs,
        isNot(contains("sourceType === 'article' && pageProgressionDirection")),
      );
      expect(
        bookJs,
        contains(
          'pageProgressionDirection: reader.view.pageProgressionDirection',
        ),
      );
      expect(viewJs, contains('get pageProgressionDirection()'));
      expect(viewJs, contains('globalThis.readflexPageProgressionDirection'));
      expect(viewJs, contains("this.pageProgressionDirection === 'rtl'"));
      expect(paginatorJs, contains('get pageProgressionDirection()'));
      expect(paginatorJs, contains('#pageProgressionRtl'));
      expect(paginatorJs, contains('const pageVelocity'));
      expect(paginatorJs, contains('this.#rtl = pageProgressionRtl'));
      expect(paginatorJs, contains("this.#scrollToPage(page, 'snap'"));
      expect(
        paginatorJs,
        isNot(contains('const pageArg = this.#rtl ? -page : page')),
      );
      expect(fixedLayoutJs, contains('get pageProgressionDirection()'));
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

  group('reader command script', () {
    test('returns null and labels async command failures', () {
      final script = buildReaderCommandScript(
        label: 'prevPage',
        expression: 'prevPage()',
      );

      expect(script, contains('const label = "prevPage";'));
      expect(script, contains('const result = prevPage();'));
      expect(script, contains("typeof result.then === 'function'"));
      expect(script, contains('result.catch(reportError);'));
      expect(
        script,
        contains("console.error('[readflex-eval:' + label + ']', message);"),
      );
      expect(script, contains('return null;'));
    });

    test('article RTL patch keeps pagination RTL and maps start to right', () {
      final script = buildArticleTextDirectionPatchScript(
        textAlign: 'start',
        justify: false,
      );

      expect(script, contains('const requestedTextAlign = "start";'));
      expect(script, contains("if (resolved === 'start') return 'right';"));
      expect(script, contains("if (resolved === 'end') return 'left';"));
      expect(script, contains("doc.documentElement.dir = 'rtl';"));
      expect(script, contains("doc.body.dir = 'rtl';"));
      expect(script, contains('readflex-article-text-direction-runtime'));
      expect(script, contains("node.style.setProperty('direction'"));
      expect(script, contains("node.style.setProperty('text-align', align"));
      expect(script, contains('[readflex-article-rtl] applied nodes='));
      expect(
        script,
        contains('html[data-readflex-text-direction="rtl"] body h1'),
      );
      expect(script, contains("'  text-align: ' + align + ' !important;'"));
      expect(script, contains('setTimeout(apply, 100);'));
    });

    test('article RTL patch command is valid JavaScript', () {
      final nodeVersion = Process.runSync('node', const ['--version']);
      if (nodeVersion.exitCode != 0) return;

      final script = buildReaderCommandScript(
        label: 'articleTextDirection',
        expression: buildArticleTextDirectionPatchScript(
          textAlign: 'start',
          justify: false,
        ),
      );
      final dir = Directory.systemTemp.createTempSync('reader_rtl_patch_test_');
      try {
        final file = File('${dir.path}/rtl_patch.js');
        file.writeAsStringSync(script);
        final result = Process.runSync('node', ['--check', file.path]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('reapplies article RTL patch after subsequent ready signals', () {
      final webViewDart = File(
        'lib/src/book_reader_webview.dart',
      ).readAsStringSync();

      expect(
        webViewDart,
        contains(
          'if (wasReady) {\n      _applyArticleTextDirectionPatch();\n      return;\n    }',
        ),
      );
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
