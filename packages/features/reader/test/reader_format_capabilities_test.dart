import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_contents_tabs.dart';
import 'package:reader/src/reader_document_features.dart';
import 'package:reader/src/reader_format_capabilities.dart';
import 'package:reader/src/reader_progress_label.dart';

const _textActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.textAppearance,
  ReaderChromeAction.bookmark,
  ReaderChromeAction.textSearch,
};

void main() {
  for (final format in [
    BookFormat.epub,
    BookFormat.fb2,
    BookFormat.mobi,
    BookFormat.azw3,
  ]) {
    test('$format keeps reflowable text controls and section progress', () {
      final policy = readerFormatCapabilitiesFor(format: format);
      expect(policy.contentKind, ReaderContentKind.text);
      expect(policy.chromeActions, _textActions);
      expect(policy.appearanceControls, ReaderAppearanceControls.text);
      expect(policy.progressMode, ReaderProgressMode.textSections);
      expect(policy.contentsMode, ReaderContentsMode.chapters);
      expect(policy.textSelection, ReaderTextSelectionSupport.always);
      expect(policy.supportsColumns, isTrue);
      expect(policy.supportsPageTurns, isTrue);
      expect(policy.supportsZoom, isFalse);
      expect(policy.allowsPageGesturesWithChrome, isFalse);
      expect(policy.showsChapterTitles, isTrue);
    });
  }

  test('PDF combines zoom and page appearance with continuous progress', () {
    final policy = readerFormatCapabilitiesFor(format: BookFormat.pdf);
    expect(policy.contentKind, ReaderContentKind.pdf);
    expect(policy.chromeActions, _textActions);
    expect(policy.appearanceControls, ReaderAppearanceControls.pages);
    expect(policy.supportsColumns, isFalse);
    expect(policy.supportsZoom, isTrue);
    expect(policy.supportsPageTurns, isTrue);
    expect(policy.progressMode, ReaderProgressMode.documentPages);
    expect(policy.progressMode.usesDiscretePages, isFalse);
    expect(policy.progressMode.usesZeroBasedPages, isTrue);
    expect(policy.progressMode.showsPageOverlay, isFalse);
    expect(policy.contentsMode, ReaderContentsMode.chaptersAndPages);
    expect(policy.textSelection, ReaderTextSelectionSupport.textLayer);
    expect(policy.allowsPageGesturesWithChrome, isFalse);
    expect(policy.showsChapterTitles, isTrue);
  });

  for (final format in [BookFormat.cbz, BookFormat.djvu]) {
    test('$format keeps discrete page progress and page-turn controls', () {
      final policy = readerFormatCapabilitiesFor(format: format);
      expect(
        policy.contentKind,
        format == BookFormat.cbz
            ? ReaderContentKind.comic
            : ReaderContentKind.djvu,
      );
      expect(policy.chromeActions, {
        ReaderChromeAction.contents,
        ReaderChromeAction.pageTurn,
        ReaderChromeAction.bookmark,
        if (format == BookFormat.djvu) ReaderChromeAction.textSearch,
      });
      expect(policy.appearanceControls, ReaderAppearanceControls.none);
      expect(policy.supportsColumns, isFalse);
      expect(policy.supportsZoom, isTrue);
      expect(policy.supportsPageTurns, isTrue);
      expect(policy.progressMode, ReaderProgressMode.imagePages);
      expect(policy.progressMode.usesDiscretePages, isTrue);
      expect(policy.progressMode.usesZeroBasedPages, isTrue);
      expect(policy.progressMode.showsPageOverlay, isTrue);
      expect(policy.progressMode.seekSettleTimeout, const Duration(seconds: 3));
      expect(policy.allowsPageGesturesWithChrome, isTrue);
      expect(policy.showsChapterTitles, isFalse);
      expect(
        policy.contentsMode,
        format == BookFormat.cbz
            ? ReaderContentsMode.pages
            : ReaderContentsMode.chaptersAndPages,
      );
      expect(
        policy.textSelection,
        format == BookFormat.cbz
            ? ReaderTextSelectionSupport.none
            : ReaderTextSelectionSupport.textLayer,
      );
      expect(
        policy.supportsImageHighlightPreviews,
        format == BookFormat.cbz,
        reason: 'This refactor preserves the existing preview support',
      );
    });
  }

  test('article policy takes precedence over any legacy book format', () {
    final article = readerFormatCapabilitiesFor(
      sourceType: SourceType.article,
      format: null,
    );
    expect(article.contentKind, ReaderContentKind.article);
    expect(article.chromeActions, _textActions);
    expect(article.appearanceControls, ReaderAppearanceControls.text);
    expect(article.progressMode, ReaderProgressMode.articleSections);
    expect(article.contentsMode, ReaderContentsMode.chapters);
    expect(article.textSelection, ReaderTextSelectionSupport.always);
    expect(article.supportsZoom, isFalse);
    expect(article.supportsColumns, isFalse);
    expect(article.supportsPageTurns, isFalse);
    for (final format in BookFormat.values) {
      expect(
        identical(
          article,
          readerFormatCapabilitiesFor(
            sourceType: SourceType.article,
            format: format,
          ),
        ),
        isTrue,
      );
      expect(
        readerContentsTabs(
          sourceType: SourceType.article,
          format: format,
          hasPageGrid: true,
        ),
        [
          ReaderContentsTab.chapters,
          ReaderContentsTab.bookmarks,
          ReaderContentsTab.highlights,
        ],
      );
      expect(
        readerProgressLabel(
          sourceType: SourceType.article,
          format: format,
          progress: .5,
          chapterCurrentPage: 2,
          chapterTotalPages: 3,
          isDragging: false,
          formatPageOfTotal: (page, total) => '$page/$total',
        ),
        '2/3',
      );
    }
  });

  test('unknown book format keeps the text-reader fallback', () {
    expect(
      identical(
        readerFormatCapabilitiesFor(format: null),
        readerFormatCapabilitiesFor(format: BookFormat.epub),
      ),
      isTrue,
    );
  });

  test('profile and action lookups reuse immutable canonical values', () {
    for (final source in SourceType.values) {
      for (final format in <BookFormat?>[...BookFormat.values, null]) {
        final first = readerFormatCapabilitiesFor(
          sourceType: source,
          format: format,
        );
        final next = readerFormatCapabilitiesFor(
          sourceType: source,
          format: format,
        );
        expect(identical(first, next), isTrue);
        expect(identical(first.chromeActions, next.chromeActions), isTrue);
        expect(() => first.chromeActions.clear(), throwsUnsupportedError);
      }
    }
  });

  test(
    'document discovery cannot change static policy or enable capabilities',
    () {
      for (final format in BookFormat.values) {
        final state = ReaderState(
          document: ReaderDocument(
            id: 'source',
            sourceType: SourceType.book,
            title: 'Source',
            filePath: '/source.${format.name}',
            format: format,
            addedAt: DateTime(2026),
          ),
        );
        final policy = state.formatCapabilities;
        for (final text in [null, false, true]) {
          final discovered = state.copyWith(
            documentFeatures: ReaderDocumentFeatures(
              format: 'untrusted-format-hint',
              hasSearchableText: text,
              hasTableOfContents: text,
              pageCount: text == null ? null : 40,
            ),
          );
          expect(identical(discovered.formatCapabilities, policy), isTrue);
          expect(discovered.documentFeatures!.hasSearchableText, text);
        }
      }
    },
  );
}
