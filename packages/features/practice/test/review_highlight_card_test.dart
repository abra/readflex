import 'dart:io';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/practice_item.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/practice_harness.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in const [
      (AppTypography.fontFamilySans, 'Geist-Variable.ttf'),
      (AppTypography.fontFamilySerif, 'Literata-Variable.ttf'),
    ]) {
      await (FontLoader(family)..addFont(
            rootBundle.load('packages/component_library/fonts/$file'),
          ))
          .load();
    }
    var root = Directory.current;
    while (!File('${root.path}/test/fonts/NotoSansArabic.ttf').existsSync()) {
      final parent = root.parent;
      if (parent.path == root.path) {
        throw StateError('Arabic test font not found');
      }
      root = parent;
    }
    final bytes = await File(
      '${root.path}/test/fonts/NotoSansArabic.ttf',
    ).readAsBytes();
    await (FontLoader('Noto Sans Arabic')..addFont(
          Future.value(ByteData.sublistView(bytes)),
        ))
        .load();
  });

  for (final (size, locale) in const [
    (Size(320, 568), Locale('en')),
    (Size(390, 844), Locale('ar')),
    (Size(844, 390), Locale('ar')),
    (Size(1024, 1366), Locale('en')),
  ]) {
    testWidgets('long highlight remains readable at 200%: $size $locale', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rtl = locale.languageCode == 'ar';
      final sentence = rtl
          ? 'القراءة تمنحنا وقتا لفهم الأفكار وربط الكلمات بتجربتنا اليومية.'
          : 'Reading gives us time to understand an idea and connect each sentence with our own experience.';
      final ending = rtl ? 'النهاية.' : 'END.';
      final quote = [
        for (var paragraph = 0; paragraph < 4; paragraph++)
          List.filled(4, sentence).join(' '),
        ending,
      ].join('\n\n');
      final note = rtl ? 'ملاحظة قصيرة.' : 'A short note.';
      var opened = 0;
      final harness = (await tester.runAsync(PracticeHarness.create))!;
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.addBook('long-highlight');
        await harness.addHighlight('long-highlight', quote, note: note);
      });
      await tester.pumpWidget(
        harness.app(
          ReviewSessionScreen(
            fsrsRepository: harness.fsrs,
            dictionaryRepository: harness.dictionary,
            highlightRepository: harness.highlights,
            bookRepository: harness.books,
            preferencesService: harness.preferences,
            onOpenInSource: (_, _) async => opened++,
          ),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await settle(tester);

      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        final quoteFinder = find.byKey(const ValueKey('reviewQuote'));
        final quoteWidget = tester.widget<Text>(quoteFinder);
        final quoteParagraph = tester.renderObject<RenderParagraph>(
          quoteFinder,
        );
        final context = tester.element(quoteFinder);
        final body = context.text.bodyLarge;
        final style = quoteWidget.style!;
        final l10n = ReadflexLocalizations.of(context)!;
        expect(quoteParagraph.text.toPlainText(), quote);
        expect(quoteWidget.maxLines, isNull);
        expect(quoteWidget.overflow, isNull);
        expect(quoteParagraph.didExceedMaxLines, isFalse);
        expect(
          quoteWidget.textDirection,
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(style.fontFamily, AppTypography.fontFamilySerif);
        expect(style.fontSize, body.fontSize);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.letterSpacing, 0);
        expect(quoteWidget.data, quote);
        expect(quoteWidget.textSpan, isNull);
        expect(style.backgroundColor, isNull);
        expect(style.background, isNull);
        expect(
          quoteParagraph.textScaler.scale(body.fontSize!),
          body.fontSize! * 2,
        );
        expect(tester.getSemantics(quoteFinder).label, quote);
        expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('reviewNote'))).data,
          note,
        );
        final location = find.byKey(const ValueKey('reviewLocation'));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('reviewSourceTitle')))
              .data,
          'A Book',
        );
        if (size.height > 390) {
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('reviewSourceDetails')))
                .data,
            'Author · Chapter 1',
          );
        } else {
          expect(
            find.byKey(const ValueKey('reviewSourceDetails')),
            findsNothing,
          );
        }
        expect(
          tester.getRect(location).bottom,
          lessThan(tester.getRect(quoteFinder).top),
        );

        final viewportFinder = find.byKey(const ValueKey('reviewCardViewport'));
        final clipFinder = find.byKey(const ValueKey('reviewCardClip'));
        final clip = tester.getRect(clipFinder);
        final panel = tester.getRect(
          find.byKey(const ValueKey('reviewControlsPanel')),
        );
        final frame = tester.getRect(
          find.byKey(const ValueKey('reviewStudyCard')),
        );
        final slot = tester.getRect(
          find.byKey(const ValueKey('reviewHighlightViewport')),
        );
        final verticalPadding = slot.height < 288
            ? AppSpacing.lg
            : AppSpacing.xl;
        expect(frame.top, closeTo(slot.top + verticalPadding, .01));
        expect(frame.left, greaterThanOrEqualTo(AppSpacing.lg));
        expect(frame.right, lessThanOrEqualTo(size.width - AppSpacing.lg));
        expect(
          frame.bottom,
          lessThanOrEqualTo(panel.top - AppSpacing.md - verticalPadding),
        );
        expect(clip.top, greaterThan(tester.getRect(location).bottom));
        expect(clip.left, greaterThan(frame.left));
        expect(clip.right, lessThan(frame.right));
        expect(clip.bottom, lessThan(frame.bottom));
        final fixedBounds = _highlightFixedBounds(tester);
        final panelSurface = tester.widget<AppSurface>(
          find.byKey(const ValueKey('reviewControlsPanel')),
        );
        expect(panelSurface.color, context.colors.surface);
        expect(panelSurface.elevation, AppElevation.level1);
        final scrollable = find
            .descendant(
              of: viewportFinder,
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        expect(find.byType(Scrollable), findsOneWidget);
        expect(
          tester.widget<SingleChildScrollView>(viewportFinder).primary,
          isFalse,
        );
        final scrollbar = tester.widget<Scrollbar>(
          find.descendant(
            of: find.byKey(const ValueKey('reviewHighlightScrollbar')),
            matching: find.byType(Scrollbar),
          ),
        );
        expect(scrollbar.controller!.position, same(position));
        final keep = find.byKey(const ValueKey('reviewRate-keep'));
        final keepBounds = tester.getRect(keep);
        expect(keep.hitTestable(), findsOneWidget);
        _expectDockedRatings(tester, size, keepBounds);
        _expectPinnedHighlightFrame(tester, fixedBounds);
        await _expectHighlightScrollbar(tester, true);

        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        _expectDockedRatings(tester, size, keepBounds);
        _expectPinnedHighlightFrame(tester, fixedBounds);
        await _expectHighlightScrollbar(tester, true);
        if (size.width == 320) {
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          await _expectHighlightScrollbar(tester, true);
        }
        final gapPoint = Offset(
          clip.center.dx,
          clip.bottom + AppSpacing.md / 2,
        );
        expect(
          quoteParagraph.localToGlobal(Offset.zero).dy +
              quoteParagraph.size.height,
          greaterThan(gapPoint.dy),
          reason: 'The long paragraph continues past the visible reading area',
        );
        expect(
          tester.hitTestOnBinding(gapPoint).path.map((entry) => entry.target),
          isNot(contains(quoteParagraph)),
          reason: 'Hidden text must not intercept the gap above the dock',
        );
        if (size.width == 320) {
          await _expectNoPaintBelowViewport(tester, quoteParagraph);
        }
        final lastLine = quoteParagraph.getBoxesForSelection(
          TextSelection(
            baseOffset: quote.length - ending.length,
            extentOffset: quote.length,
          ),
        );
        expect(lastLine, isNotEmpty);
        final viewport = tester.getRect(viewportFinder);
        final lastRect = MatrixUtils.transformRect(
          quoteParagraph.getTransformTo(null),
          lastLine.last.toRect(),
        );
        position.jumpTo(
          (position.pixels + lastRect.bottom - viewport.bottom + 12).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(keep),
          keepBounds,
          reason: 'Rating stays available while the passage scrolls',
        );
        for (final box in lastLine) {
          final rect = MatrixUtils.transformRect(
            quoteParagraph.getTransformTo(null),
            box.toRect(),
          );
          expect(rect.top, greaterThanOrEqualTo(viewport.top));
          expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        }

        expect(quoteParagraph.text.toPlainText(), quote);
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        _expectDockedRatings(tester, size, keepBounds);
        _expectPinnedHighlightFrame(tester, fixedBounds);
        await _expectHighlightScrollbar(tester, true);
        expect(
          find.byKey(const ValueKey('reviewNote')).hitTestable(),
          findsOneWidget,
        );
        final endingOffset = position.pixels;
        await tester.tap(find.byKey(const ValueKey('reviewOpenInBook')));
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(position.pixels, endingOffset);
        _expectPinnedHighlightFrame(tester, fixedBounds);
        for (final (id, label) in [
          ('keep', l10n.practiceKeep),
          ('showLess', l10n.practiceShowLess),
        ]) {
          final rating = find.byKey(ValueKey('reviewRate-$id'));
          expect(rating.hitTestable(), findsOneWidget);
          final bounds = tester.getRect(rating);
          expect(bounds.width, greaterThanOrEqualTo(48));
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          final node = tester.getSemantics(rating);
          expect(node.label, label);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(ValueKey(rtl ? 'reviewRate-showLess' : 'reviewRate-keep')),
        );
        await settle(tester);
        expect(find.byType(ReviewSessionSummary), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets('the next long highlight starts at the top of its passage', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(PracticeHarness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.addBook('two-passages');
      for (final opening in ['First passage.', 'Second passage.']) {
        await harness.addHighlight(
          'two-passages',
          '$opening\n\n${List.filled(50, 'Each paragraph deserves time to read.').join('\n\n')}',
        );
      }
    });
    await tester.pumpWidget(
      harness.app(
        ReviewSessionScreen(
          fsrsRepository: harness.fsrs,
          dictionaryRepository: harness.dictionary,
          highlightRepository: harness.highlights,
          bookRepository: harness.books,
          preferencesService: harness.preferences,
          onOpenInSource: (_, _) async {},
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await settle(tester);
    final firstText = tester
        .widget<Text>(find.byKey(const ValueKey('reviewQuote')))
        .data;
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('reviewCardViewport')),
          matching: find.byType(Scrollable),
        )
        .first;
    final firstPosition = tester.state<ScrollableState>(scrollable).position;
    firstPosition.jumpTo(firstPosition.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reviewRate-keep')));
    await settle(tester);

    final nextPosition = tester.state<ScrollableState>(scrollable).position;
    expect(nextPosition, isNot(same(firstPosition)));
    expect(nextPosition.pixels, 0);
    expect(nextPosition.maxScrollExtent, greaterThan(0));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('reviewQuote'))).data,
      isNot(firstText),
    );
    expect(
      find.byKey(const ValueKey('reviewLocation')).hitTestable(),
      findsOneWidget,
    );
    await _expectHighlightScrollbar(tester, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (size, locale, scale, title, author, direction) in [
    (
      const Size(390, 844),
      const Locale('en'),
      1.0,
      'A Book',
      'An Author',
      TextDirection.ltr,
    ),
    (
      const Size(320, 568),
      const Locale('ar'),
      2.0,
      List.filled(12, 'كتاب طويل عن القراءة والأفكار').join(' '),
      List.filled(8, 'اسم الكاتب').join(' '),
      TextDirection.rtl,
    ),
    (
      const Size(1024, 1366),
      const Locale('en'),
      2.0,
      List.filled(12, 'A long book title about reading').join(' '),
      List.filled(8, 'The author of this book').join(' '),
      TextDirection.ltr,
    ),
    (
      const Size(320, 568),
      const Locale('ar'),
      2.0,
      'Readwise: a collection of saved ideas from books and articles for a thoughtful life',
      'An Author',
      TextDirection.ltr,
    ),
    (
      const Size(844, 390),
      const Locale('ar'),
      2.0,
      List.filled(12, 'كتاب طويل عن القراءة والأفكار').join(' '),
      List.filled(8, 'اسم الكاتب').join(' '),
      TextDirection.rtl,
    ),
  ]) {
    testWidgets(
      'source header remains readable and opens the passage: $size $locale ${scale}x',
      (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(PracticeHarness.create))!;
        addTearDown(harness.dispose);
        String? expectedCfi;
        await tester.runAsync(() async {
          await harness.addBook('source-header', title: title, author: author);
          expectedCfi = (await harness.addHighlight(
            'source-header',
            'A short saved passage.',
          )).cfiRange;
        });
        final opened = <(String, String?)>[];
        await _mountReview(
          tester,
          harness,
          locale: locale,
          textScaler: TextScaler.linear(scale),
          onOpenInSource: (id, cfi) async => opened.add((id, cfi)),
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          final dense = size.height == 390;
          final titleFinder = find.byKey(const ValueKey('reviewSourceTitle'));
          final authorFinder = find.byKey(
            ValueKey(scale == 1 ? 'reviewSourceAuthor' : 'reviewSourceDetails'),
          );
          for (final (finder, expected) in [
            (titleFinder, title),
            if (!dense)
              (authorFinder, scale == 1 ? author : '$author · Chapter 1'),
          ]) {
            final text = tester.widget<Text>(finder);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.text.toPlainText(), expected);
            expect(text.maxLines, finder == titleFinder && !dense ? 2 : 1);
            expect(text.overflow, TextOverflow.ellipsis);
            expect(
              paragraph.textSize.width,
              lessThanOrEqualTo(paragraph.size.width + .01),
            );
            expect(
              text.textDirection,
              direction,
            );
          }
          if (dense) {
            for (final id in [
              'reviewSourceAuthor',
              'reviewSourceChapter',
              'reviewSourceDetails',
            ]) {
              expect(find.byKey(ValueKey(id)), findsNothing);
            }
          }
          final sourceAction = find.byKey(const ValueKey('reviewOpenInBook'));
          expect(tester.getSize(sourceAction).height, greaterThanOrEqualTo(48));
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('reviewControlsPanel')),
              matching: find.byKey(const ValueKey('reviewOpenInBook')),
            ),
            findsNothing,
          );
          final headerSemantics = tester.getSemantics(
            find.bySemanticsLabel(title),
          );
          expect(headerSemantics.label, contains(title));
          expect(headerSemantics.value, contains(author));
          expect(
            headerSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          final tooltips = tester.widgetList<Tooltip>(
            find.descendant(
              of: find.byKey(const ValueKey('reviewLocation')),
              matching: find.byType(Tooltip),
            ),
          );
          expect(
            tooltips.any(
              (tooltip) =>
                  tooltip.message?.contains(title) == true &&
                  tooltip.message?.contains(author) == true,
            ),
            isTrue,
          );
          final quoteParagraph = tester.renderObject<RenderParagraph>(
            find.byKey(const ValueKey('reviewQuote')),
          );
          final firstQuoteLine = quoteParagraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 1),
              )
              .first
              .toRect();
          final quoteStart = MatrixUtils.transformRect(
            quoteParagraph.getTransformTo(null),
            firstQuoteLine,
          );
          final readingArea = tester.getRect(
            find.byKey(const ValueKey('reviewCardClip')),
          );
          // Selection boxes can extend a fraction beyond the font's line box.
          expect(quoteStart.top, greaterThanOrEqualTo(readingArea.top - 1));
          expect(
            quoteStart.bottom,
            lessThanOrEqualTo(readingArea.bottom + 1),
            reason: 'Secondary metadata must leave the start of the passage visible',
          );
          if (scale == 1) {
            final cover = find.byKey(const ValueKey('reviewSourceCover'));
            expect(tester.getSize(cover), const Size(40, 60));
            expect(
              find.descendant(of: cover, matching: find.byType(AppCoverArt)),
              findsOneWidget,
            );
            final card = tester.getRect(
              find.byKey(const ValueKey('reviewStudyCard')),
            );
            final topBar = tester.getRect(find.byType(ReviewSessionTopBar));
            final panel = tester.getRect(
              find.byKey(const ValueKey('reviewControlsPanel')),
            );
            expect(card.top, closeTo(topBar.bottom + AppSpacing.xl, .01));
            expect(
              card.bottom,
              lessThan(panel.top - AppSpacing.md - AppSpacing.xl),
            );
            await _expectHighlightScrollbar(tester, false);
          } else {
            expect(
              find.byKey(const ValueKey('reviewSourceCover')),
              findsNothing,
            );
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('reviewLocation')),
                matching: find.byType(Icon),
              ),
              findsNothing,
            );
          }
          final titleParagraph = tester.renderObject<RenderParagraph>(
            titleFinder,
          );
          expect(titleParagraph.didExceedMaxLines, scale > 1);
          final firstGlyph = titleParagraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 1),
              )
              .first
              .toRect();
          await tester.tapAt(titleParagraph.localToGlobal(firstGlyph.center));
          await tester.pumpAndSettle();
          expect(opened, [('source-header', expectedCfi)]);
          if (scale == 1) {
            await tester.longPressAt(
              titleParagraph.localToGlobal(firstGlyph.center),
            );
            await tester.pumpAndSettle();
            expect(find.text('$title\n$author\nChapter 1'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }

  for (final author in [null, ' \n ']) {
    testWidgets(
      'readonly article uses publisher when author is absent: $author',
      (
        tester,
      ) async {
        final harness = (await tester.runAsync(PracticeHarness.create))!;
        addTearDown(harness.dispose);
        const title = 'An article worth keeping';
        const publisher = 'A publication';
        final source = LibrarySource.fromArticle(
          Article(
            id: 'saved-article',
            title: title,
            author: author,
            siteName: publisher,
            hostname: 'example.org',
            url: 'https://example.org/article',
            contentPath: 'content.json',
            addedAt: DateTime(2026),
          ),
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            harness.app(
              Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: SizedBox(
                    width: 480,
                    height: 480,
                    child: ReviewHighlightCard(
                      item: PracticeHighlightItem(
                        highlight: Highlight(
                          id: 'article-highlight',
                          sourceId: source.id,
                          sourceType: SourceType.article,
                          text: 'The complete saved passage.',
                          createdAt: DateTime(2026),
                        ),
                        fsrs: const FsrsCardData(),
                        source: source,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('reviewSourceAuthor')))
                .data,
            publisher,
          );
          expect(find.byKey(const ValueKey('reviewOpenInBook')), findsNothing);
          expect(
            tester
                .getSemantics(find.text(title))
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isFalse,
          );
          expect(
            find.text('The complete saved passage.').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }

  for (final missingSource in [false, true]) {
    testWidgets(
      'missing source metadata does not invent a title or author: $missingSource',
      (
        tester,
      ) async {
        final harness = (await tester.runAsync(PracticeHarness.create))!;
        addTearDown(harness.dispose);
        await tester.runAsync(() async {
          if (!missingSource) {
            await harness.addBook('missing-metadata', title: '', author: null);
          }
          await harness.addHighlight('missing-metadata', 'A saved passage.');
        });
        final opened = <String>[];
        await _mountReview(
          tester,
          harness,
          onOpenInSource: (id, _) async => opened.add(id),
        );
        expect(find.byKey(const ValueKey('reviewSourceTitle')), findsNothing);
        expect(find.byKey(const ValueKey('reviewSourceAuthor')), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('reviewSourceChapter')))
              .data,
          'Chapter 1',
        );
        if (missingSource) {
          expect(find.byKey(const ValueKey('reviewSourceCover')), findsNothing);
        }
        await tester.tap(find.byKey(const ValueKey('reviewOpenInBook')));
        await tester.pumpAndSettle();
        expect(opened, ['missing-metadata']);
        expect(find.byKey(const ValueKey('reviewQuote')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('a passage without metadata has no empty source header', (
    tester,
  ) async {
    final harness = (await tester.runAsync(PracticeHarness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(
      () => harness.addHighlight(
        'missing-source',
        'The passage remains available.',
        chapterTitle: ' \n ',
      ),
    );
    await _mountReview(tester, harness);
    expect(find.byKey(const ValueKey('reviewLocation')), findsNothing);
    expect(find.byKey(const ValueKey('reviewOpenInBook')), findsNothing);
    expect(find.byKey(const ValueKey('reviewSourceCover')), findsNothing);
    expect(
      find.byKey(const ValueKey('reviewQuote')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reviewRate-keep')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a 50k passage and a long note expose their complete endings', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final quote =
        '${List.filled(850, 'A saved idea remains readable in its complete original context.').join('\n\n')}\n\nEND OF PASSAGE.';
    final note =
        '${List.filled(180, 'A personal note can also contain several paragraphs.').join('\n\n')}\n\nEND OF NOTE.';
    expect(quote.length, greaterThan(50000));
    final harness = (await tester.runAsync(PracticeHarness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.addBook('extreme-passage');
      await harness.addHighlight('extreme-passage', quote, note: note);
    });
    await _mountReview(tester, harness, textScaler: const TextScaler.linear(2));
    final viewport = tester.getRect(
      find.byKey(const ValueKey('reviewCardViewport')),
    );
    final keepBounds = tester.getRect(
      find.byKey(const ValueKey('reviewRate-keep')),
    );
    final fixedBounds = _highlightFixedBounds(tester);
    for (final (key, expected) in [
      ('reviewQuote', quote),
      ('reviewNote', note),
    ]) {
      final finder = find.byKey(ValueKey(key));
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.text.toPlainText(), expected);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.width, lessThanOrEqualTo(viewport.width));
      expect(paragraph.size.height.isFinite, isTrue);
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      await _revealTextEnd(tester, finder);
      _expectDockedRatings(tester, const Size(320, 568), keepBounds);
      _expectPinnedHighlightFrame(tester, fixedBounds);
      await _expectHighlightScrollbar(tester, true);
    }
    expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reviewRate-keep')));
    await settle(tester);
    expect(find.byType(ReviewSessionSummary), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (note, size, locale) in const [
    (null, Size(320, 568), Locale('en')),
    ('', Size(390, 844), Locale('ar')),
    (' \n\t ', Size(1024, 1366), Locale('en')),
  ]) {
    testWidgets('short highlight without a note at 200%: $size $locale $note', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(PracticeHarness.create))!;
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.addBook('no-note');
        await harness.addHighlight('no-note', 'A saved passage.', note: note);
      });
      await tester.pumpWidget(
        harness.app(
          ReviewSessionScreen(
            fsrsRepository: harness.fsrs,
            dictionaryRepository: harness.dictionary,
            highlightRepository: harness.highlights,
            bookRepository: harness.books,
            preferencesService: harness.preferences,
            onOpenInSource: (_, _) async {},
          ),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await settle(tester);
      final l10n = ReadflexLocalizations.of(
        tester.element(find.byKey(const ValueKey('reviewQuote'))),
      )!;
      expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
      expect(find.byKey(const ValueKey('reviewNote')), findsNothing);
      expect(find.text(l10n.readerHighlightNoteTitle), findsNothing);
      expect(find.text(l10n.practiceNoNote), findsNothing);
      await _expectHighlightScrollbar(tester, false);
      final shortFrame = tester.getRect(
        find.byKey(const ValueKey('reviewStudyCard')),
      );
      final shortPanel = tester.getRect(
        find.byKey(const ValueKey('reviewControlsPanel')),
      );
      expect(
        shortFrame.bottom,
        lessThan(shortPanel.top - AppSpacing.md - AppSpacing.xl),
      );
      _expectDockedRatings(
        tester,
        size,
        tester.getRect(find.byKey(const ValueKey('reviewRate-keep'))),
      );
      for (final rating in ['keep', 'showLess']) {
        expect(
          find.byKey(ValueKey('reviewRate-$rating')).hitTestable(),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('reviewRate-keep')));
      await settle(tester);
      expect(find.byType(ReviewSessionSummary), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _mountReview(
  WidgetTester tester,
  PracticeHarness harness, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  Future<void> Function(String, String?)? onOpenInSource,
}) async {
  await tester.pumpWidget(
    harness.app(
      ReviewSessionScreen(
        fsrsRepository: harness.fsrs,
        dictionaryRepository: harness.dictionary,
        highlightRepository: harness.highlights,
        bookRepository: harness.books,
        preferencesService: harness.preferences,
        onOpenInSource: onOpenInSource ?? (_, _) async {},
      ),
      locale: locale,
      textScaler: textScaler,
    ),
  );
  await settle(tester);
}

Future<void> _revealTextEnd(WidgetTester tester, Finder finder) async {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  final lastLine = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: text.length - 1, extentOffset: text.length),
      )
      .last
      .toRect();
  final viewportFinder = find.byKey(const ValueKey('reviewCardViewport'));
  final viewport = tester.getRect(viewportFinder);
  final position = tester
      .state<ScrollableState>(
        find
            .descendant(of: viewportFinder, matching: find.byType(Scrollable))
            .first,
      )
      .position;
  final end = MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    lastLine,
  );
  position.jumpTo(
    (position.pixels + end.bottom - viewport.bottom + AppSpacing.md).clamp(
      0.0,
      position.maxScrollExtent,
    ),
  );
  await tester.pumpAndSettle();
  final visibleEnd = MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    lastLine,
  );
  expect(visibleEnd.top, greaterThanOrEqualTo(viewport.top));
  expect(visibleEnd.bottom, lessThanOrEqualTo(viewport.bottom));
}

void _expectDockedRatings(WidgetTester tester, Size size, Rect keepBounds) {
  expect(
    tester.getRect(find.byKey(const ValueKey('reviewRate-keep'))),
    keepBounds,
  );
  for (final id in ['keep', 'showLess']) {
    final rating = find.byKey(ValueKey('reviewRate-$id'));
    expect(rating.hitTestable(), findsOneWidget);
    final bounds = tester.getRect(rating);
    expect(bounds.width, greaterThanOrEqualTo(48));
    expect(bounds.height, greaterThanOrEqualTo(48));
    expect(bounds.bottom, lessThanOrEqualTo(size.height));
  }
}

Map<Key, Rect> _highlightFixedBounds(WidgetTester tester) => {
  for (final id in ['reviewStudyCard', 'reviewLocation', 'reviewOpenInBook'])
    ValueKey(id): tester.getRect(find.byKey(ValueKey(id))),
};

void _expectPinnedHighlightFrame(WidgetTester tester, Map<Key, Rect> bounds) {
  for (final entry in bounds.entries) {
    expect(tester.getRect(find.byKey(entry.key)), entry.value);
  }
  expect(
    find.byKey(const ValueKey('reviewOpenInBook')).hitTestable(),
    findsOneWidget,
  );
}

Future<void> _expectHighlightScrollbar(
  WidgetTester tester,
  bool visible,
) async {
  final scrollbar = find.byKey(const ValueKey('reviewHighlightScrollbar'));
  final controller = tester
      .widget<Scrollbar>(
        find.descendant(of: scrollbar, matching: find.byType(Scrollbar)),
      )
      .controller!;
  expect(controller.position.maxScrollExtent > 0, visible);
  expect(
    find.descendant(
      of: find.byType(ReviewHighlightCard),
      matching: find.byType(Scrollable),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: find.byType(ReviewHighlightCard),
      matching: find.byType(ScrollEdgeFadeStack),
    ),
    findsNothing,
  );
  final paintFinder = find
      .descendant(
        of: scrollbar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is ScrollbarPainter,
        ),
      )
      .first;
  final painter =
      tester.widget<CustomPaint>(paintFinder).foregroundPainter!
          as ScrollbarPainter;
  final size = tester.getSize(paintFinder);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final bytes = (await tester.runAsync(() async {
    try {
      final image = await picture.toImage(
        size.width.ceil(),
        size.height.ceil(),
      );
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }))!;
  final pixels = bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  var hasThumb = false;
  for (var offset = 3; offset < pixels.length; offset += 4) {
    if (pixels[offset] > 0) {
      hasThumb = true;
      break;
    }
  }
  expect(
    hasThumb,
    visible,
    reason: 'A thumb is visible only when the card body can scroll',
  );
}

Future<void> _expectNoPaintBelowViewport(
  WidgetTester tester,
  RenderParagraph paragraph,
) async {
  RenderObject viewport = paragraph;
  while (!viewport.isRepaintBoundary) {
    viewport = viewport.parent!;
  }
  final box = viewport as RenderBox;
  final layer = viewport.debugLayer! as OffsetLayer;
  final width = box.size.width.ceil();
  final height = box.size.height.ceil();
  final bytes = (await tester.runAsync(() async {
    final image = await layer.toImage(
      Rect.fromLTWH(0, 0, width.toDouble(), height + 24),
    );
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  }))!;
  final pixels = bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  var hasVisibleContent = false;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      hasVisibleContent |= pixels[(y * width + x) * 4 + 3] > 0;
    }
  }
  expect(hasVisibleContent, isTrue);
  for (var y = height + 1; y < height + 24; y++) {
    for (var x = 0; x < width; x++) {
      expect(
        pixels[(y * width + x) * 4 + 3],
        0,
        reason: 'Reading content paints below its viewport at ($x, $y)',
      );
    }
  }
}
