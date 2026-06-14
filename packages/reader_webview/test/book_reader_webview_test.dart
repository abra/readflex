import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

String readBookReaderWebViewLibrarySource() => [
  'lib/src/book_reader_webview.dart',
  'lib/src/book_reader_webview_helpers.dart',
  'lib/src/book_reader_webview_widget.dart',
  'lib/src/book_reader_webview_state.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

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

  group('reader bridge callbacks', () {
    test('shared tap handler forwards to the current widget callback', () {
      final webViewDart = readBookReaderWebViewLibrarySource();

      expect(
        webViewDart,
        contains('onTapped: (x, y) => widget.onTapped?.call(x, y)'),
      );
      expect(webViewDart, isNot(contains('onTapped: widget.onTapped')));
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

  group('shouldAttemptWebContentRecovery', () {
    test('allows one retry for saved CFI restores', () {
      expect(
        shouldAttemptWebContentRecovery(
          initialCfi: 'epubcfi(/6/14!/4/2)',
          isArticle: false,
          recoveryAttempts: 0,
          maxRecoveryAttempts: 1,
          recoveryInProgress: false,
        ),
        isTrue,
      );
    });

    test('allows one retry for fresh articles without a saved CFI', () {
      expect(
        shouldAttemptWebContentRecovery(
          initialCfi: null,
          isArticle: true,
          recoveryAttempts: 0,
          maxRecoveryAttempts: 1,
          recoveryInProgress: false,
        ),
        isTrue,
      );
    });

    test('does not retry non-article opens without a saved CFI', () {
      expect(
        shouldAttemptWebContentRecovery(
          initialCfi: null,
          isArticle: false,
          recoveryAttempts: 0,
          maxRecoveryAttempts: 1,
          recoveryInProgress: false,
        ),
        isFalse,
      );
    });

    test('does not retry after the attempt budget is exhausted', () {
      expect(
        shouldAttemptWebContentRecovery(
          initialCfi: 'epubcfi(/6/14!/4/2)',
          isArticle: true,
          recoveryAttempts: 1,
          maxRecoveryAttempts: 1,
          recoveryInProgress: false,
        ),
        isFalse,
      );
    });

    test('does not retry while a recovery reload is already in progress', () {
      expect(
        shouldAttemptWebContentRecovery(
          initialCfi: 'epubcfi(/6/14!/4/2)',
          isArticle: true,
          recoveryAttempts: 0,
          maxRecoveryAttempts: 1,
          recoveryInProgress: true,
        ),
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
      expect(bookJs, contains('window.pageLeft'));
      expect(bookJs, contains('window.pageRight'));
      expect(bookJs, contains('window.pageLeft = () => reader.view.goLeft()'));
      expect(
        bookJs,
        contains('window.pageRight = () => reader.view.goRight()'),
      );
      expect(bookJs, contains('globalThis.readflexSourceType = sourceType'));
      expect(bookJs, contains('normalizeLoadedDocument(doc)'));
      expect(bookJs, contains("callFlutter('onSearch'"));
      expect(bookJs, contains("callFlutter('onDocumentFeatures'"));
      expect(bookJs, contains("callFlutter('handleBookmark'"));
    });

    test('uses a safe footnote dialog fallback on Android WebView', () {
      final bookJs = File(
        'assets/foliate-js/src/book.js',
      ).readAsStringSync();

      expect(bookJs, contains('const openFootnoteDialog = () =>'));
      expect(
        bookJs,
        contains("typeof footnoteDialog.showModal === 'function'"),
      );
      expect(bookJs, contains("footnoteDialog.setAttribute('open', '')"));
      expect(bookJs, contains('const closeFootnoteDialog = () =>'));
      expect(
        bookJs,
        contains('window.isFootNoteOpen = () => isFootnoteDialogOpen()'),
      );
      expect(
        bookJs,
        contains('window.closeFootNote = () => closeFootnoteDialog()'),
      );
      expect(
        bookJs,
        isNot(contains('e.target === footnoteDialog ? footnoteDialog.close()')),
      );
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
      final webViewDart = readBookReaderWebViewLibrarySource();

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
        contains('#bookmarkVisualPageAnchorFromLocation('),
      );
      expect(bookJs, contains('#bookmarkSectionIndexFromLocation(location)'));
      expect(bookJs, contains('location?.section?.current'));
      expect(
        bookJs,
        contains('#bookmarkVisualContentFromLocation(location)'),
      );
      expect(bookJs, contains('#normalizedBookmarkAnnotation(annotation)'));
      expect(bookJs, contains('#annotationSpineIndex(annotation)'));
      expect(bookJs, contains('#annotationCfiSpineIndex(annotation)'));
      expect(
        bookJs,
        contains('annotation?.anchorSectionIndex'),
      );
      expect(bookJs, contains('if (!visibleRange || !this.#doc)'));
      expect(bookJs, contains('cfi = this.view.getCFI(sectionIndex)'));
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
      expect(bookJs, contains('const cfiSectionIndex ='));
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
      expect(bookJs, contains('this.view.getCFI(sectionIndex, anchorRange)'));
      expect(bookJs, contains('currentAnchor?.anchorSectionIndex'));
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

    test(
      'keeps preformatted content wrapped without aggressive word breaks',
      () {
        final bookJs = File(
          'assets/foliate-js/src/book.js',
        ).readAsStringSync();

        expect(bookJs, contains('pre {'));
        expect(bookJs, contains('white-space: pre-wrap !important;'));
        expect(bookJs, contains('inline-size: 100%;'));
        expect(bookJs, contains('max-inline-size: 100%;'));
        expect(bookJs, contains('overflow-x: hidden !important;'));
        expect(bookJs, contains('overflow-wrap: break-word !important;'));
        expect(bookJs, contains('word-break: normal !important;'));
        expect(bookJs, isNot(contains('-webkit-overflow-scrolling: touch;')));
      },
    );

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
      expect(
        bookJs,
        contains(
          "import { normalizeSelectionRange } from './readflex_selection_normalizer.js'",
        ),
      );
      expect(bookJs, contains('normalizeLoadedDocument(doc)'));
      expect(bookJs, contains('normalizeSelectionRange(range)'));
      expect(
        normalizerJs,
        contains('export const normalizeLoadedDocument = doc =>'),
      );
      expect(normalizerJs, contains('markInlineImages(doc)'));
      expect(normalizerJs, contains('wrapWideTables(doc)'));
      expect(normalizerJs, contains("wrapper.setAttribute('cfi-skip', '')"));
      expect(normalizerJs, contains('applyWideTableGestureGuard(doc)'));
      expect(normalizerJs, contains('normalizeCodeLikeBlocks(doc)'));
      expect(assetExtractor, contains('readflex_document_normalizer.js'));
      expect(assetExtractor, contains('readflex_selection_normalizer.js'));
      expect(assetExtractor, contains("reader_webview_assets_60"));
    });

    test('keeps same-node marked selection adjacent to punctuation', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();

      expect(
        bookJs,
        contains(r'return _limitContext(`${before}[[${selected}]]${after}`);'),
      );
      expect(
        bookJs,
        isNot(
          contains(
            r'return _limitContext(`${before} [[${selected}]] ${after}`);',
          ),
        ),
      );
    });

    test('does not dump full reader style changes to console', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();

      expect(bookJs, isNot(contains("console.log('changeStyle'")));
      expect(bookJs, isNot(contains('JSON.stringify(style)')));
    });

    test('limits WebContent crash recovery to one eligible reload', () {
      final webViewDart = readBookReaderWebViewLibrarySource();

      expect(webViewDart, contains('_maxWebContentRecoveryAttempts = 1'));
      expect(webViewDart, contains('shouldAttemptWebContentRecovery('));
      expect(webViewDart, contains('article without initial CFI'));
      expect(
        webViewDart,
        contains('skipping reload to avoid a recovery loop'),
      );
      expect(webViewDart, contains('_webContentRecoveryAttempts += 1'));
      expect(webViewDart, contains('_webContentRecoveryAttempts = 0'));
    });

    test('bundles only supported format adapters', () {
      final assetExtractor = File(
        'lib/src/asset_extractor.dart',
      ).readAsStringSync();

      expect(assetExtractor, contains('assets/foliate-js/src/pdf.js'));
      expect(assetExtractor, contains('assets/foliate-js/src/fb2.js'));
      expect(assetExtractor, contains('assets/foliate-js/src/mobi.js'));
      expect(assetExtractor, contains('assets/foliate-js/src/comic-book.js'));
    });

    test('closes foliate book resources when view is closed', () {
      final viewJs = File('assets/foliate-js/src/view.js').readAsStringSync();

      expect(viewJs, contains('this.book?.destroy?.()'));
    });

    test('fixed-layout animates page turns when animation is enabled', () {
      final fixedLayoutJs = File(
        'assets/foliate-js/src/fixed-layout.js',
      ).readAsStringSync();

      expect(fixedLayoutJs, contains('#shouldAnimate(direction)'));
      expect(fixedLayoutJs, contains("this.hasAttribute('animated')"));
      expect(fixedLayoutJs, contains('#animateSpreadTurn'));
      expect(fixedLayoutJs, contains('#animateSideTurn'));
      expect(fixedLayoutJs, contains('get pageTurnAxisVertical()'));
      expect(
        fixedLayoutJs,
        contains("this.getAttribute('page-turn-axis') === 'vertical'"),
      );
      expect(fixedLayoutJs, contains('#spreadTurnTransform(offset)'));
      expect(fixedLayoutJs, contains('#frameTurnTransform(offset)'));
      expect(fixedLayoutJs, contains(r'translate3d(0, ${offset}, 0)'));
      expect(
        fixedLayoutJs,
        contains(r'translate3d(-50%, calc(-50% + ${offset}), 0)'),
      );
      expect(fixedLayoutJs, contains('#nextTurnDirection()'));
      expect(fixedLayoutJs, contains('#prevTurnDirection()'));
      expect(
        fixedLayoutJs,
        contains('return this.pageTurnAxisVertical ? 1 : this.rtl ? -1 : 1'),
      );
      expect(
        fixedLayoutJs,
        contains('return this.pageTurnAxisVertical ? -1 : this.rtl ? 1 : -1'),
      );
      expect(fixedLayoutJs, contains('this.#nextTurnDirection()'));
      expect(fixedLayoutJs, contains('this.#prevTurnDirection()'));
      expect(fixedLayoutJs, contains('get atStart()'));
      expect(fixedLayoutJs, contains('get atEnd()'));
      expect(fixedLayoutJs, contains('#canGoLeftWithinSpread()'));
      expect(fixedLayoutJs, contains('#canGoRightWithinSpread()'));
      expect(
        fixedLayoutJs,
        contains('return !canGoWithinSpread && this.#index >= lastIndex'),
      );
      expect(fixedLayoutJs, contains('previousSpread?.remove()'));
      expect(fixedLayoutJs, contains('this.#locked = true'));
    });

    test('fixed-layout swipe follows the configured page-turn axis', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();

      expect(bookJs, contains('swipe-flip-fixed-layout'));
      expect(
        bookJs,
        contains('const verticalTurn = renderer.pageTurnAxisVertical === true'),
      );
      expect(
        bookJs,
        contains('const primaryDelta = verticalTurn ? deltaY : deltaX'),
      );
      expect(
        bookJs,
        contains('const crossDelta = verticalTurn ? deltaX : deltaY'),
      );
      expect(
        bookJs,
        contains('Math.abs(primaryDelta) <= Math.abs(crossDelta)'),
      );
      expect(bookJs, contains('Math.abs(primaryDelta) < 30'));
      expect(bookJs, contains('primaryDelta / (deltaT || 1)'));
      expect(bookJs, contains('if (primaryDelta > 0) renderer.prev?.()'));
      expect(bookJs, isNot(contains('Math.abs(deltaX) <= Math.abs(deltaY)')));
    });

    test('comic fixed-layout renderer gets a safe horizontal writing mode', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();

      expect(bookJs, contains('const rendererWritingMode = () => {'));
      expect(
        bookJs,
        contains(
          "return typeof value === 'string' && value ? value : 'horizontal-tb'",
        ),
      );
      expect(
        bookJs,
        contains(
          'isVerticalWritingMode(style.writingMode) || isVerticalWritingMode(rendererWritingMode())',
        ),
      );
      expect(bookJs, contains('writingMode: rendererWritingMode()'));
      expect(
        bookJs,
        isNot(contains('reader.view.renderer.writingMode.startsWith')),
      );
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
      expect(bookJs, contains('const shouldRefreshLayoutForStyle ='));
      expect(
        bookJs,
        contains('return oldStyle.writingMode !== nextStyle.writingMode'),
      );
      expect(
        bookJs,
        isNot(contains("value === 'scroll' || value === 'vertical'")),
      );
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
        contains("setRendererAttribute(renderer, 'no-continuous-scroll'"),
      );
      expect(
        bookJs,
        contains('if (shouldUpdateReaderCSS(oldStyle, newStyle, turn.scroll))'),
      );
      expect(
        bookJs,
        contains('reader.view.renderer.setStyles?.(getCSS(newStyle))'),
      );
    });

    test("keeps vertical page turn on the paginated layout", () {
      final bookJs = File("assets/foliate-js/src/book.js").readAsStringSync();
      final paginatorJs = File(
        "assets/foliate-js/src/paginator.js",
      ).readAsStringSync();

      expect(bookJs, contains("case 'vertical':"));
      expect(bookJs, contains("turn.scroll = false"));
      expect(
        bookJs,
        contains("setRendererAttribute(renderer, 'page-turn-axis'"),
      );
      expect(
        bookJs,
        contains(
          "style.pageTurnStyle === 'vertical' ? 'vertical' : 'horizontal'",
        ),
      );
      expect(bookJs, contains("|| this.view.renderer.pageTurnAxisVertical"));
      expect(paginatorJs, contains("'page-turn-axis'"));
      expect(
        paginatorJs,
        contains("case 'page-turn-axis':\n        this.render()"),
      );
      expect(paginatorJs, contains("get pageTurnAxisVertical()"));
      expect(
        paginatorJs,
        contains("const verticalTurn = this.pageTurnAxisVertical"),
      );
      expect(paginatorJs, contains("} else if (this.pageTurnAxisVertical) {"));
      expect(
        paginatorJs,
        contains("this.#container.style.overflowX = 'hidden'"),
      );
      expect(
        paginatorJs,
        contains(
          "if (horizontalDrag && horizontalAxis && this.pageTurnAxisVertical)",
        ),
      );
      expect(
        paginatorJs,
        contains("const horizontalLocked = state?.direction === 'horizontal'"),
      );
      expect(
        paginatorJs,
        contains(
          "this.pageTurnAxisVertical && (reason === 'page' || reason === 'snap')",
        ),
      );
      expect(paginatorJs, contains("opts.verticalPageDirection"));
      expect(
        paginatorJs,
        contains("const extent = this.#verticalDragPreviewExtent() || size"),
      );
      expect(paginatorJs, contains('const easeInOutSine = x =>'));
      expect(
        paginatorJs,
        contains('const targetLayer = this.#view?.createPagePreview(offset)'),
      );
      expect(paginatorJs, contains('this.#top.append(targetLayer)'));
      expect(paginatorJs, contains('viewElement.style.transform'));
      expect(paginatorJs, contains('targetLayer.style.transform'));
      expect(paginatorJs, contains('element[scrollProp] = offset'));
      expect(
        paginatorJs,
        contains('const preventDefaultIfCancelable = event =>'),
      );
      expect(paginatorJs, contains('if (!event?.cancelable) return false'));
      expect(
        paginatorJs,
        contains('preventDefault: () => preventDefaultIfCancelable(e)'),
      );
      expect(
        paginatorJs,
        isNot(contains('preventDefault: () => e.preventDefault()')),
      );
      expect(paginatorJs, contains('createPagePreview(scrollOffset)'));
      expect(
        paginatorJs,
        contains('element.style.cssText = this.#element.style.cssText'),
      );
      expect(
        paginatorJs,
        contains('frame.style.cssText = this.#iframe.style.cssText'),
      );
      expect(paginatorJs, contains('const sanitizePagePreview = root =>'));
      expect(paginatorJs, contains('sanitizePagePreview(root)'));
      expect(paginatorJs, contains("name === 'srcdoc'"));
      expect(paginatorJs, contains("name.startsWith('on')"));
      expect(paginatorJs, contains("value.startsWith('javascript:')"));
      expect(paginatorJs, contains("frame.srcdoc = `<!doctype html>"));
      expect(
        paginatorJs,
        contains(
          "frame.setAttribute('sandbox', 'allow-same-origin allow-scripts')",
        ),
      );
      expect(
        paginatorJs,
        contains("this.#updateVerticalDragPreview(deltaY, state)"),
      );
      expect(
        paginatorJs,
        contains("this.#finishVerticalDragPreview(state)"),
      );
      expect(
        paginatorJs,
        contains(
          "this.#container[this.scrollProp] = this.#pageOffset(targetPage)",
        ),
      );
      expect(paginatorJs, contains("opts.verticalPageDirection = direction"));
      expect(
        paginatorJs,
        contains(
          "supportsSmooth && reason !== 'page' && !opts.forceJsAnimation",
        ),
      );
      expect(
        paginatorJs,
        isNot(contains("const pageStepColumnWidth = Math.max(0, size - gap)")),
      );
    });
    test('guards pagination while iframe document body is unavailable', () {
      final paginatorJs = File(
        'assets/foliate-js/src/paginator.js',
      ).readAsStringSync();

      expect(paginatorJs, contains('if (!doc?.body) return'));
      expect(paginatorJs, contains('if (!el?.style) return'));
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

      expect(viewJs, contains('directionCountsFromText'));
      expect(viewJs, contains('normalizeDocumentLanguageAndDirection'));
      expect(viewJs, contains('normalizeDocumentLanguageAndDirection(doc, {'));
      expect(viewJs, contains('sourceType: globalThis.readflexSourceType'));
      expect(normalizerJs, contains('const rtlSampleRegex'));
      expect(
        normalizerJs,
        contains('export const directionCountsFromText = text =>'),
      );
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

    test('stabilizes inferred page progression for mixed-language books', () {
      final viewJs = File('assets/foliate-js/src/view.js').readAsStringSync();
      final paginatorJs = File(
        'assets/foliate-js/src/paginator.js',
      ).readAsStringSync();

      expect(
        viewJs,
        contains('const inferBookPageProgressionDirection = async'),
      );
      expect(viewJs, contains('const directionSampleSections = sections =>'));
      expect(viewJs, contains('BOOK_DIRECTION_SAMPLE_SECTION_LIMIT = 12'));
      expect(viewJs, contains('SECTION_DIRECTION_SAMPLE_SLICE_LIMIT = 3'));
      expect(viewJs, contains('const directionSampleText = text =>'));
      expect(viewJs, contains('Math.floor((count - 1) / 2)'));
      expect(
        viewJs,
        contains('const counts = directionCountsFromText(sample)'),
      );
      expect(
        viewJs,
        isNot(contains("book?.dir === 'rtl' || book?.dir === 'ltr'")),
      );
      expect(
        viewJs,
        contains("return rtlCount > ltrCount ? 'rtl' : 'ltr'"),
      );
      expect(
        viewJs,
        contains('this.book.dir = inferredPageProgressionDirection'),
      );
      expect(
        viewJs,
        contains(
          'globalThis.readflexPageProgressionDirection ||= inferredPageProgressionDirection',
        ),
      );
      expect(
        paginatorJs,
        contains('const explicitPageProgressionDirection'),
      );
      expect(
        paginatorJs,
        contains("explicitPageProgressionDirection === 'rtl'"),
      );
      expect(paginatorJs, contains(': rtl'));
    });

    test('guards NCX TOC items without direct hrefs', () {
      final bookJs = File('assets/foliate-js/src/book.js').readAsStringSync();
      final epubJs = File('assets/foliate-js/src/epub.js').readAsStringSync();

      expect(epubJs, contains('const firstNavigableHref = items => items'));
      expect(epubJs, contains(r"$content?.getAttribute('src')"));
      expect(
        epubJs,
        contains('href: href || firstNavigableHref(subitems)'),
      );
      expect(
        bookJs,
        contains('this.view.lastLocation?.section?.current'),
      );
      expect(
        bookJs,
        contains('this.view.resolveNavigation?.(href)'),
      );
      expect(
        bookJs,
        contains("if (typeof href !== 'string' || !href) return null"),
      );
      expect(
        bookJs,
        contains("href: typeof item.href === 'string' ? item.href : ''"),
      );
      expect(bookJs, contains('startPage: startPercentage == null'));
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
      final webViewDart = readBookReaderWebViewLibrarySource();

      expect(webViewDart, contains('void pageLeft()'));
      expect(webViewDart, contains("expression: 'pageLeft()'"));
      expect(webViewDart, contains('void pageRight()'));
      expect(webViewDart, contains("expression: 'pageRight()'"));
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
      expect(viewJs, contains("return direction === 'rtl' ? 'rtl' : 'ltr'"));
      expect(viewJs, contains('goLeft()'));
      expect(
        viewJs,
        contains(
          "return this.pageProgressionDirection === 'rtl' ? this.next() : this.prev()",
        ),
      );
      expect(viewJs, contains('goRight()'));
      expect(
        viewJs,
        contains(
          "return this.pageProgressionDirection === 'rtl' ? this.prev() : this.next()",
        ),
      );
      expect(paginatorJs, contains('get pageProgressionDirection()'));
      expect(paginatorJs, contains('#pageProgressionRtl'));
      expect(paginatorJs, contains('const pageVelocity'));
      expect(
        paginatorJs,
        contains(
          'const invertProgression = this.#pageProgressionRtl && !verticalTurn && !this.#vertical && !pageStepVertical',
        ),
      );
      expect(
        paginatorJs,
        contains('this.#container.scrollLeft = startScroll - deltaX'),
      );
      expect(paginatorJs, contains('WebKit/Chromium scrollLeft direction'));
      expect(paginatorJs, contains('if (this.#locked) return'));
      expect(paginatorJs, contains('finally {'));
      expect(paginatorJs, contains('this.#locked = false'));
      expect(
        paginatorJs,
        contains('if (page <= 0) return this.#adjacentIndex(-1) != null'),
      );
      expect(
        paginatorJs,
        contains(
          'if (page >= pages - 1) return this.#adjacentIndex(1) != null',
        ),
      );
      expect(paginatorJs, contains('return !this.atStart'));
      expect(paginatorJs, contains('return !this.atEnd'));
      expect(paginatorJs, isNot(contains('const animateScroll = (element,')));
      expect(paginatorJs, isNot(contains('useTransformAnimation')));
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
      final webViewDart = readBookReaderWebViewLibrarySource();

      expect(
        webViewDart,
        contains(
          'if (wasReady) {\n      _applyArticleTextDirectionPatch();\n      return;\n    }',
        ),
      );
    });

    test('exposes a guarded clear-selection command', () {
      final webViewDart = readBookReaderWebViewLibrarySource();

      expect(webViewDart, contains('void clearSelection()'));
      expect(webViewDart, contains("label: 'clearSelection'"));
      expect(
        webViewDart,
        contains(
          "typeof window.clearSelection === 'function' ? window.clearSelection() : null",
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
