import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:library_feature/src/library_content_scroll_view.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_list_cover_slot.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

final _article = LibrarySource.fromArticle(
  Article(
    id: 'a-1',
    title: 'The Long Read',
    author: 'Ada Writer',
    url: 'https://example.com/long',
    siteName: 'Example',
    contentPath: '/articles/a-1/article.json',
    addedAt: DateTime(2026),
    // 12000 chars at 1200/min: 10 minutes; 58% left rounds up to 6.
    textLength: 12000,
    readingProgress: 0.42,
    lastOpenedAt: DateTime(2026, 2, 1),
  ),
);

final _book = LibrarySource.fromBook(
  Book(
    id: 'b-1',
    title: 'Flutter in Action',
    author: 'Eric Windmill',
    filePath: '/books/flutter.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
    readingProgress: 0.42,
    lastOpenedAt: DateTime(2026, 2, 1),
  ),
);

final _card = find.byType(LibraryContinueReadingCard);
final _caption = find.byKey(const ValueKey('libraryContinueReadingCaption'));

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    LibrarySource source, {
    VoidCallback? onPressed,
    VoidCallback? onLongPressed,
    bool isSelectionMode = false,
    bool isSelected = false,
    ThemeData? theme,
    TextDirection direction = TextDirection.ltr,
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: LibraryContinueReadingCard(
                    source: source,
                    isSelectionMode: isSelectionMode,
                    isSelected: isSelected,
                    onPressed: onPressed ?? () {},
                    onLongPressed: onLongPressed ?? () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('LibraryContinueReadingCard', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('an inset rounded panel with a compact source cover: '
          '${theme.brightness}', (tester) async {
        await pumpCard(tester, _article, theme: theme);
        final material = tester.widget<Material>(
          find.byKey(const ValueKey('libraryContinueReadingCard')),
        );
        expect(material.color, theme.colorScheme.surfaceContainerLow);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(AppRadius.lg));
        expect(shape.side.color, theme.colorScheme.outlineVariant);
        final ink = tester.widget<InkWell>(
          find.descendant(of: _card, matching: find.byType(InkWell)),
        );
        expect(ink.borderRadius, BorderRadius.circular(AppRadius.lg));

        final card = tester.getRect(_card);
        final cover = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingCover')),
        );
        expect(card.width, 390);
        expect(card.height, kLibraryListCoverHeight + AppSpacing.lg * 2);
        final panel = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingCard')),
        );
        expect(panel.left - card.left, AppSpacing.lg);
        expect(card.right - panel.right, AppSpacing.lg);
        expect(
          cover.size,
          const Size(kLibraryListCoverWidth, kLibraryListCoverHeight),
        );
        expect(cover.left - panel.left, AppSpacing.lg);
        expect(cover.center.dy, closeTo(card.center.dy, .01));
        expect(cover.top - card.top, AppSpacing.lg);
        expect(card.bottom - cover.bottom, AppSpacing.lg);
        expect(
          find.descendant(
            of: _card,
            matching: find.byType(LibraryListCoverSlot),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _card,
            matching: find.byType(AppSourceCoverFrame),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('text roles: overline, serif title, muted author', (
      tester,
    ) async {
      await pumpCard(tester, _article);
      final strings = tester.element(_card).l10n;
      final theme = Theme.of(tester.element(_card));
      final overline = tester.widget<Text>(
        find.text(strings.libraryContinueReading),
      );
      expect(overline.style!.fontSize, theme.textTheme.labelSmall!.fontSize);
      expect(overline.style!.color, theme.colorScheme.onSurfaceVariant);

      final title = tester.widget<Text>(find.text('The Long Read'));
      expect(title.maxLines, greaterThan(0));
      expect(title.overflow, isNull);
      expect(title.style!.fontSize, theme.textTheme.titleMedium!.fontSize);
      expect(title.style!.fontFamily, AppTypography.fontFamilySerif);

      final author = tester.widget<Text>(find.text('Ada Writer'));
      expect(author.maxLines, 1);
      expect(author.style!.fontSize, theme.textTheme.bodySmall!.fontSize);
      expect(author.style!.color, theme.colorScheme.onSurfaceVariant);

      final cover = tester.getRect(
        find.byKey(const ValueKey('libraryContinueReadingCover')),
      );
      final overlineRect = tester.getRect(
        find.text(strings.libraryContinueReading),
      );
      expect(overlineRect.left - cover.right, kLibraryListCoverToTextGap);
      expect(
        tester.getRect(find.text('The Long Read')).top,
        greaterThan(overlineRect.bottom),
      );
    });

    testWidgets('wide windows give reading a larger cover and title', (
      tester,
    ) async {
      await pumpCard(tester, _article, width: 1032);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('libraryContinueReadingCover')),
        ),
        const Size(80, 120),
      );
      final title = tester.widget<Text>(find.text(_article.title));
      expect(
        title.style!.fontSize,
        AppTheme.light().textTheme.titleLarge!.fontSize,
      );
      expect(
        tester.getSize(_card).height,
        120 + AppSpacing.lg * 2,
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in [800.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final direction in TextDirection.values) {
          testWidgets('tablet reading metadata remains readable and tappable: '
              '$width / $scale / $direction', (tester) async {
            var opened = 0;
            await pumpCard(
              tester,
              _article,
              width: width,
              textScale: scale,
              direction: direction,
              onPressed: () => opened++,
            );
            final context = tester.element(_card);
            for (final finder in [
              find.byKey(const ValueKey('libraryContinueReadingContext')),
              _caption,
            ]) {
              final paragraph = tester.renderObject<RenderParagraph>(finder);
              expect(paragraph.didExceedMaxLines, isFalse);
              expect(
                tester.getRect(_card).contains(tester.getCenter(finder)),
                isTrue,
              );
            }
            expect(
              tester.widget<Text>(_caption).style!.fontSize,
              Theme.of(context).textTheme.bodyMedium!.fontSize,
            );
            final expanded = find.byKey(
              const ValueKey('libraryContinueReadingExpandedContent'),
            );
            expect(expanded, scale == 2 ? findsOneWidget : findsNothing);
            await tester.tap(_card);
            await tester.pump();
            expect(opened, 1);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    group('long titles', () {
      // The square test font at titleMedium: 14 glyphs per 252dp line.
      const twoLineTitle = 'Flutter Patterns Apps';
      const longTitle = 'Flutter Patterns and Best Practices';
      final absurdTitle = List.filled(40, 'Very').join(' ');
      final titleFinder = find.byKey(
        const ValueKey('libraryContinueReadingTitle'),
      );

      LibrarySource bookTitled(String title) => LibrarySource.fromBook(
        Book(
          id: 'b-long',
          title: title,
          author: 'Ada Writer',
          filePath: '/books/long.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          readingProgress: 0.42,
          lastOpenedAt: DateTime(2026, 2, 1),
        ),
      );

      Future<({double card, double title, double fontSize})> measure(
        WidgetTester tester,
        String title,
      ) async {
        await pumpCard(tester, bookTitled(title));
        return (
          card: tester.getSize(_card).height,
          title: tester.getSize(titleFinder).height,
          fontSize: tester.widget<Text>(titleFinder).style!.fontSize!,
        );
      }

      testWidgets('two lines keep the full title size', (tester) async {
        final theme = AppTheme.light();
        final twoLines = await measure(tester, twoLineTitle);
        expect(twoLines.fontSize, theme.textTheme.titleMedium!.fontSize);
        final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
        expect(paragraph.didExceedMaxLines, isFalse);
        final role = theme.textTheme.titleMedium!;
        expect(
          paragraph.size.height,
          closeTo(role.fontSize! * role.height! * 2, 1),
        );
      });

      testWidgets(
        'title length keeps the card and following content in place',
        (
          tester,
        ) async {
          double? height;
          Rect? cover;
          Rect? progress;
          Rect? caption;
          for (final title in [
            'Short',
            twoLineTitle,
            longTitle,
            absurdTitle,
          ]) {
            final measured = await measure(tester, title);
            final currentCover = tester.getRect(
              find.byKey(const ValueKey('libraryContinueReadingCover')),
            );
            final currentProgress = tester.getRect(
              find.byKey(const ValueKey('libraryContinueReadingProgress')),
            );
            final currentCaption = tester.getRect(_caption);
            height ??= measured.card;
            cover ??= currentCover;
            progress ??= currentProgress;
            caption ??= currentCaption;
            expect(measured.card, closeTo(height, 0.01), reason: title);
            expect(currentCover, cover, reason: title);
            expect(currentProgress, progress, reason: title);
            expect(currentCaption, caption, reason: title);
            expect(
              tester
                  .renderObject<RenderParagraph>(titleFinder)
                  .didExceedMaxLines,
              isFalse,
              reason: 'the full title fits',
            );
            expect(tester.widget<Text>(titleFinder).overflow, isNull);
            expect(
              tester.getRect(find.text('Ada Writer')).top -
                  tester.getRect(titleFinder).bottom,
              closeTo(AppSpacing.xxs, 0.01),
              reason: 'the author stays immediately below the title',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('a longer title shrinks to fit whole in two lines', (
        tester,
      ) async {
        final twoLines = await measure(tester, twoLineTitle);
        final long = await measure(tester, longTitle);

        expect(long.fontSize, lessThan(twoLines.fontSize));
        final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.widget<Text>(titleFinder).overflow, isNull);
        expect(long.title, lessThanOrEqualTo(twoLines.title + 0.5));
        expect(long.card, closeTo(twoLines.card, 0.01));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'an extreme title shrinks until it fits whole without growing',
        (
          tester,
        ) async {
          final twoLines = await measure(tester, twoLineTitle);
          final absurd = await measure(tester, absurdTitle);

          expect(absurd.fontSize, greaterThan(0));
          expect(absurd.fontSize, lessThan(twoLines.fontSize));
          final text = tester.widget<Text>(titleFinder);
          expect(text.data, absurdTitle);
          expect(text.overflow, isNull);
          expect(text.maxLines, greaterThan(2));
          expect(
            tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
            isFalse,
          );
          expect(absurd.card, closeTo(twoLines.card, 0.01));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'large text gives the full title its own space at its role size',
        (
          tester,
        ) async {
          await pumpCard(
            tester,
            bookTitled(longTitle),
            textScale: 2,
          );
          final cover = tester.getRect(
            find.byKey(const ValueKey('libraryContinueReadingCover')),
          );
          final title = tester.getRect(titleFinder);
          final author = tester.getRect(find.text('Ada Writer'));
          expect(title.top, greaterThan(cover.bottom));
          expect(author.top, greaterThan(title.bottom));
          final role = AppTheme.light().textTheme.titleMedium!;
          final titleText = tester.widget<Text>(titleFinder);
          final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
          expect(titleText.style!.fontSize, role.fontSize);
          expect(titleText.maxLines, isNull);
          expect(
            paragraph.textScaler.scale(titleText.style!.fontSize!),
            role.fontSize! * 2,
          );
          expect(
            tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
            isFalse,
          );
          expect(tester.widget<Text>(titleFinder).overflow, isNull);
          expect(
            tester.getSize(_card).height,
            greaterThan(kLibraryListCoverHeight + AppSpacing.lg * 2),
          );
          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets('omits the author line without an author', (tester) async {
      final anonymous = LibrarySource.fromBook(
        Book(
          id: 'b-2',
          title: 'Anonymous',
          filePath: '/b2.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          readingProgress: 0.5,
          lastOpenedAt: DateTime(2026, 2, 1),
        ),
      );
      await pumpCard(tester, anonymous);
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: _card, matching: find.byType(Text)),
          )
          .map((text) => text.data)
          .toList();
      expect(texts, unorderedEquals(['Continue reading', 'Anonymous', '50%']));
    });

    for (final direction in TextDirection.values) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          'compact card geometry stays stable on a 320dp phone '
          '$direction textScale=$textScale',
          (tester) async {
            final anonymous = LibrarySource.fromBook(
              Book(
                id: 'anonymous',
                title: 'Anonymous',
                filePath: '/anonymous.epub',
                format: BookFormat.epub,
                addedAt: DateTime(2026),
                readingProgress: 0.42,
              ),
            );
            final longArticle = LibrarySource.fromArticle(
              Article(
                id: 'long-article',
                title: List.filled(30, 'Long article title').join(' '),
                url: 'https://example.com/longest',
                contentPath: '/longest.json',
                addedAt: DateTime(2026),
                textLength: 1200 * 180,
                readingProgress: 0.5,
              ),
            );
            double? height;
            double? progressTop;
            double? captionTop;
            for (final (source, selected) in [
              (_book, false),
              (_article, false),
              (anonymous, false),
              (longArticle, false),
              (longArticle, true),
            ]) {
              await pumpCard(
                tester,
                source,
                width: 320,
                textScale: textScale,
                direction: direction,
                isSelectionMode: selected,
                isSelected: selected,
              );
              final card = tester.getRect(_card);
              final cover = tester.getRect(
                find.byKey(const ValueKey('libraryContinueReadingCover')),
              );
              final progress = tester.getRect(
                find.byKey(const ValueKey('libraryContinueReadingProgress')),
              );
              final caption = tester.getRect(_caption);
              height ??= card.height;
              progressTop ??= progress.top;
              captionTop ??= caption.top;
              expect(card.width, 320);
              expect(card.height, kLibraryListCoverHeight + AppSpacing.lg * 2);
              expect(card.height, closeTo(height, 0.01));
              expect(cover.top - card.top, AppSpacing.lg);
              expect(card.bottom - cover.bottom, AppSpacing.lg);
              expect(cover.center.dy, closeTo(card.center.dy, 0.01));
              expect(
                cover.size,
                const Size(kLibraryListCoverWidth, kLibraryListCoverHeight),
              );
              expect(progress.top, closeTo(progressTop, 0.01));
              expect(caption.top, closeTo(captionTop, 0.01));
              expect(progress.height, 4);
              expect(progress.bottom, cover.bottom);
              expect(
                direction == TextDirection.ltr
                    ? cover.left - card.left
                    : card.right - cover.right,
                AppSpacing.lg * 2,
              );
              expect(
                direction == TextDirection.ltr
                    ? progress.left - cover.right
                    : cover.left - progress.right,
                kLibraryListCoverToTextGap,
              );
              expect(caption.left, greaterThanOrEqualTo(AppSpacing.lg));
              expect(caption.right, lessThanOrEqualTo(320 - AppSpacing.lg));
              expect(tester.widget<Text>(_caption).maxLines, 1);
              expect(
                tester.widget<Text>(_caption).overflow,
                TextOverflow.ellipsis,
              );
              final titleFinder = find.byKey(
                const ValueKey('libraryContinueReadingTitle'),
              );
              expect(tester.widget<Text>(titleFinder).data, source.title);
              expect(tester.widget<Text>(titleFinder).overflow, isNull);
              expect(
                tester
                    .renderObject<RenderParagraph>(titleFinder)
                    .didExceedMaxLines,
                isFalse,
              );
              for (final text
                  in find
                      .descendant(of: _card, matching: find.byType(Text))
                      .evaluate()) {
                final rect = tester.getRect(find.byWidget(text.widget));
                expect(rect.top, greaterThanOrEqualTo(cover.top - 0.01));
                expect(rect.bottom, lessThanOrEqualTo(cover.bottom + 0.01));
              }
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }

    testWidgets(
      'very large text keeps the title and complete source semantics',
      (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpCard(tester, _article, width: 320, textScale: 4);
          final cover = tester.getRect(
            find.byKey(const ValueKey('libraryContinueReadingCover')),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('libraryContinueReadingTitle')),
          );
          final progress = tester.getRect(
            find.byKey(const ValueKey('libraryContinueReadingProgress')),
          );
          expect(tester.getSize(_card).height, greaterThan(cover.height));
          expect(title.top, greaterThan(cover.bottom));
          expect(title.bottom, lessThanOrEqualTo(progress.top));
          expect(progress.bottom, tester.getRect(_card).bottom - AppSpacing.lg);
          expect(_caption, findsOneWidget);
          final titleText = tester.widget<Text>(
            find.byKey(const ValueKey('libraryContinueReadingTitle')),
          );
          expect(
            titleText.style!.fontSize,
            AppTheme.light().textTheme.titleMedium!.fontSize,
          );
          expect(titleText.maxLines, isNull);
          expect(
            tester
                .renderObject<RenderParagraph>(
                  find.byKey(const ValueKey('libraryContinueReadingTitle')),
                )
                .didExceedMaxLines,
            isFalse,
          );
          final node = tester.getSemantics(_card);
          expect(node.label, 'The Long Read');
          expect(node.value, '42 percent read, 6 min left');
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    for (final direction in TextDirection.values) {
      testWidgets(
        'expanded 200% card keeps long title, context and source actions: '
        '$direction',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final source = LibrarySource.fromBook(
              Book(
                id: 'long-expanded',
                title: direction == TextDirection.rtl
                    ? List.filled(12, 'كتاب عن القراءة والتعلّم').join(' ')
                    : List.filled(12, 'Reading and learning').join(' '),
                author: 'Ada Writer',
                filePath: '/long-expanded.epub',
                format: BookFormat.epub,
                addedAt: DateTime(2026),
                readingProgress: .42,
              ),
            );
            var opened = 0;
            var selected = 0;
            await pumpCard(
              tester,
              source,
              width: 320,
              textScale: 2,
              direction: direction,
              isSelectionMode: true,
              isSelected: true,
              onPressed: () => opened++,
              onLongPressed: () => selected++,
            );
            final title = find.byKey(
              const ValueKey('libraryContinueReadingTitle'),
            );
            final contextLabel = find.byKey(
              const ValueKey('libraryContinueReadingContext'),
            );
            final progress = find.byKey(
              const ValueKey('libraryContinueReadingProgress'),
            );
            final role = AppTheme.light().textTheme.titleMedium!;
            final titleText = tester.widget<Text>(title);
            final paragraph = tester.renderObject<RenderParagraph>(title);
            expect(titleText.data, source.title);
            expect(titleText.maxLines, isNull);
            expect(titleText.overflow, isNull);
            expect(titleText.style!.fontSize, role.fontSize);
            expect(
              paragraph.textScaler.scale(role.fontSize!),
              role.fontSize! * 2,
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              tester
                  .renderObject<RenderParagraph>(contextLabel)
                  .didExceedMaxLines,
              isFalse,
            );
            expect(tester.widget<Text>(contextLabel).maxLines, isNull);
            expect(tester.widget<Text>(_caption).maxLines, isNull);
            expect(tester.widget<Text>(_caption).overflow, isNull);
            expect(tester.getSemantics(_card).label, source.title);
            await tester.tap(contextLabel);
            await tester.longPress(contextLabel);
            await tester.pumpAndSettle();
            expect(opened, 1);
            expect(selected, 1);
            await tester.ensureVisible(progress);
            await tester.pumpAndSettle();
            expect(progress.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets('caption shows percent and time left', (tester) async {
      await pumpCard(tester, _article);
      expect(tester.widget<Text>(_caption).data, '42% · 6 min left');
      final theme = Theme.of(tester.element(_caption));
      expect(
        tester.widget<Text>(_caption).style!.fontSize,
        theme.textTheme.bodySmall!.fontSize,
      );
    });

    testWidgets('caption shows hours past sixty minutes', (tester) async {
      final long = LibrarySource.fromArticle(
        Article(
          id: 'a-2',
          title: 'Very Long',
          url: 'https://example.com/very-long',
          contentPath: '/a2.json',
          addedAt: DateTime(2026),
          // 90 minutes left.
          textLength: 1200 * 180,
          readingProgress: 0.5,
          lastOpenedAt: DateTime(2026, 2, 1),
        ),
      );
      await pumpCard(tester, long);
      expect(tester.widget<Text>(_caption).data, '50% · 1 h 30 min left');
    });

    testWidgets('caption omits the time when the length is unknown', (
      tester,
    ) async {
      await pumpCard(tester, _book);
      expect(tester.widget<Text>(_caption).data, '42%');
      expect(find.textContaining('min left'), findsNothing);
    });

    for (final direction in TextDirection.values) {
      testWidgets('4dp progress bar fills from the start: $direction', (
        tester,
      ) async {
        await pumpCard(tester, _article, direction: direction);
        final track = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingProgress')),
        );
        final fill = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingProgressFill')),
        );
        expect(track.height, 4);
        expect(fill.height, 4);
        expect(fill.width, closeTo(track.width * .42, .5));
        if (direction == TextDirection.ltr) {
          expect(fill.left, track.left);
        } else {
          expect(fill.right, track.right);
        }
        final context = tester.element(
          find.byKey(const ValueKey('libraryContinueReadingProgressFill')),
        );
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(
                  const ValueKey('libraryContinueReadingProgressFill'),
                ),
              )
              .color,
          context.actionForeground,
        );
        expect(
          tester
              .widget<ColoredBox>(
                find
                    .descendant(
                      of: find.byKey(
                        const ValueKey('libraryContinueReadingProgress'),
                      ),
                      matching: find.byType(ColoredBox),
                    )
                    .first,
              )
              .color,
          context.colors.surfaceContainerHighest,
        );
      });
    }

    group('progress fill animation', () {
      final fillFinder = find.byKey(
        const ValueKey('libraryContinueReadingProgressFill'),
      );
      final trackFinder = find.byKey(
        const ValueKey('libraryContinueReadingProgress'),
      );
      final later = LibrarySource.fromBook(
        Book(
          id: 'b-1',
          title: 'Flutter in Action',
          author: 'Eric Windmill',
          filePath: '/books/flutter.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          readingProgress: 0.8,
          lastOpenedAt: DateTime(2026, 2, 1),
        ),
      );

      testWidgets('eases to a new progress like the grid covers', (
        tester,
      ) async {
        await pumpCard(tester, _book);
        final track = tester.getSize(trackFinder).width;
        expect(tester.getSize(fillFinder).width, closeTo(track * .42, .5));

        await pumpCard(tester, later);
        expect(
          tester.getSize(fillFinder).width,
          closeTo(track * .42, .5),
          reason: 'the fill starts from the old value',
        );
        await tester.pump(const Duration(milliseconds: 100));
        final mid = tester.getSize(fillFinder).width;
        expect(mid, greaterThan(track * .42));
        expect(mid, lessThan(track * .8));

        await tester.pump(AppMotion.short);
        expect(tester.getSize(fillFinder).width, closeTo(track * .8, .5));
      });

      testWidgets('another book taking the card does not animate', (
        tester,
      ) async {
        await pumpCard(tester, _book);
        await pumpCard(
          tester,
          LibrarySource.fromBook(
            Book(
              id: 'b-2',
              title: 'Another Book',
              filePath: '/books/another.epub',
              format: BookFormat.epub,
              addedAt: DateTime(2026),
              readingProgress: 0.8,
              lastOpenedAt: DateTime(2026, 3, 1),
            ),
          ),
        );
        final track = tester.getSize(trackFinder).width;
        expect(tester.getSize(fillFinder).width, closeTo(track * .8, .5));
      });

      testWidgets('reduced motion sets the new progress at once', (
        tester,
      ) async {
        Future<void> pump(LibrarySource source) => tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            supportedLocales: ReadflexSupportedLocales.locales,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 390,
                    child: LibraryContinueReadingCard(
                      source: source,
                      onPressed: () {},
                      onLongPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await pump(_book);
        await pump(later);
        await tester.pump();
        final track = tester.getSize(trackFinder).width;
        expect(tester.getSize(fillFinder).width, closeTo(track * .8, .5));
      });
    });

    testWidgets('is one button: title label, progress and time value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpCard(tester, _article);
        final strings = tester.element(_card).l10n;
        expect(
          tester.getSemantics(_card),
          matchesSemantics(
            label: 'The Long Read',
            value: '42 percent read, 6 min left',
            isButton: true,
            hasTapAction: true,
            hasLongPressAction: true,
            onTapHint: strings.librarySourceOpenReader,
            onLongPressHint: strings.librarySourceSelect,
          ),
        );

        await pumpCard(tester, _book);
        expect(
          tester.getSemantics(_card).getSemanticsData().value,
          '42 percent read',
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('tap opens the source; long-press selects without opening', (
      tester,
    ) async {
      var pressed = 0;
      var longPressed = 0;
      await pumpCard(
        tester,
        _article,
        onPressed: () => pressed++,
        onLongPressed: () => longPressed++,
      );
      await tester.longPress(_card);
      await tester.pumpAndSettle();
      expect(longPressed, 1);
      expect(pressed, 0, reason: 'releasing a long-press does not open');
      await tester.tap(_card);
      expect(pressed, 1);
      expect(longPressed, 1);
    });

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('selects like a row: ${theme.brightness}', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final colors = theme.colorScheme;
          Color? textColor(String text) =>
              tester.widget<Text>(find.text(text)).style!.color;
          final check = find.descendant(
            of: _card,
            matching: find.byKey(const ValueKey('libraryListSelectionCheck')),
          );

          await pumpCard(tester, _article, theme: theme, isSelectionMode: true);
          final strings = tester.element(_card).l10n;
          expect(
            tester
                .widget<Material>(
                  find.byKey(const ValueKey('libraryContinueReadingCard')),
                )
                .color,
            colors.surfaceContainerLow,
          );
          expect(check, findsNothing);
          expect(textColor('The Long Read'), colors.onSurface);
          expect(
            tester.getSemantics(_card),
            matchesSemantics(
              label: 'The Long Read',
              value: '42 percent read, 6 min left',
              isButton: true,
              hasSelectedState: true,
              hasTapAction: true,
              hasLongPressAction: true,
              onTapHint: strings.librarySourceSelect,
            ),
          );

          await pumpCard(
            tester,
            _article,
            theme: theme,
            isSelectionMode: true,
            isSelected: true,
          );
          expect(
            tester
                .widget<Material>(
                  find.byKey(const ValueKey('libraryContinueReadingCard')),
                )
                .color,
            colors.selectedControlBackground,
          );
          expect(check, findsOneWidget);
          final fill = tester.widget<ColoredBox>(
            find.byKey(const ValueKey('libraryContinueReadingProgressFill')),
          );
          expect(fill.color, colors.selectedControlForeground);
          // Light mode's selected fill is translucent over the page.
          final band = Color.alphaBlend(
            colors.selectedControlBackground,
            theme.scaffoldBackgroundColor,
          );
          expect(
            _contrast(fill.color, band),
            greaterThanOrEqualTo(3),
            reason: 'the fill stays visible on the selected band',
          );
          for (final text in [
            'The Long Read',
            'Ada Writer',
            strings.libraryContinueReading,
          ]) {
            expect(
              textColor(text),
              colors.selectedControlForeground,
              reason: text,
            );
          }
          expect(
            tester.getSemantics(_card),
            matchesSemantics(
              label: 'The Long Read',
              value: '42 percent read, 6 min left',
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              hasTapAction: true,
              hasLongPressAction: true,
              onTapHint: strings.librarySourceDeselect,
            ),
          );
        } finally {
          semantics.dispose();
        }
      });
    }
  });

  group('placement', () {
    final rows = [
      for (final id in ['r-1', 'r-2'])
        LibrarySource.fromBook(
          Book(
            id: id,
            title: 'Row $id',
            filePath: '/$id.epub',
            format: BookFormat.epub,
            addedAt: DateTime(2026),
          ),
        ),
    ];

    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      supportedLocales: ReadflexSupportedLocales.locales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 390, height: 700, child: child),
        ),
      ),
    );

    testWidgets('list: first item on the gutter, 16dp above the first cover', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      LibrarySource? opened;
      await tester.pumpWidget(
        host(
          LibraryContentScrollView(
            layoutMode: LibraryLayoutMode.list,
            sources: rows,
            continueReadingSource: _article,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (source) => opened = source,
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      );
      final card = tester.getRect(_card);
      expect(card.left, 0);
      expect(card.right, 390);
      expect(card.top, kLibraryContentTopPadding);
      final firstCover = tester.getRect(
        find.byKey(const ValueKey('libraryListCoverSlot')).first,
      );
      expect(firstCover.top - card.bottom, kLibraryContinueReadingGap);
      // The inset panel keeps one inner gutter around its cover and title.
      final cardCover = tester.getRect(
        find.byKey(const ValueKey('libraryContinueReadingCover')),
      );
      expect(cardCover.left - firstCover.left, AppSpacing.lg);
      expect(cardCover.size, firstCover.size);
      expect(
        tester.getRect(find.text('The Long Read')).left -
            tester.getRect(find.text('Row r-1')).left,
        AppSpacing.lg,
      );
      // The first source row still has no top hairline.
      expect(
        find.byKey(const ValueKey('libraryListRowTopDivider')),
        findsOneWidget,
      );
      await tester.tap(_card);
      expect(opened, _article);

      // It scrolls with the rows.
      controller.jumpTo(40);
      await tester.pump();
      expect(tester.getRect(_card).top, kLibraryContentTopPadding - 40);
    });

    testWidgets('list without a card starts with the first row', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          LibraryContentScrollView(
            layoutMode: LibraryLayoutMode.list,
            sources: rows,
            selection: const LibrarySelectionState(),
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      );
      expect(_card, findsNothing);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('libraryListCoverSlot')).first)
            .top,
        kLibraryContentTopPadding,
      );
    });

    for (final direction in TextDirection.values) {
      testWidgets('grid: full-width first item, 16dp above the covers: '
          '$direction', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        LibrarySource? opened;
        await tester.pumpWidget(
          host(
            Directionality(
              textDirection: direction,
              child: LibraryContentScrollView(
                layoutMode: LibraryLayoutMode.grid,
                sources: rows,
                continueReadingSource: _article,
                selection: const LibrarySelectionState(),
                scrollController: controller,
                onSourcePressed: (source) => opened = source,
                onSourceLongPressed: (_) {},
                onConfirmSwipeDelete: (_) async => false,
              ),
            ),
          ),
        );
        final card = tester.getRect(_card);
        expect(card.left, 0);
        expect(card.right, 390);
        expect(card.top, kLibraryContentTopPadding);
        final cardCover = tester.getRect(
          find.byKey(const ValueKey('libraryContinueReadingCover')),
        );
        final covers = find.descendant(
          of: find.byType(SliverGrid),
          matching: find.byType(AppSourceCoverFrame),
        );
        final firstCover = tester.getRect(covers.first);
        expect(firstCover.top - card.bottom, kLibraryContinueReadingGap);
        if (direction == TextDirection.ltr) {
          expect(firstCover.left, AppSpacing.lg);
          expect(cardCover.left - firstCover.left, AppSpacing.lg);
        } else {
          expect(firstCover.right, 390 - AppSpacing.lg);
          expect(firstCover.right - cardCover.right, AppSpacing.lg);
        }
        await tester.tap(_card);
        expect(opened, _article);
        controller.jumpTo(40);
        await tester.pump();
        expect(tester.getRect(_card).top, kLibraryContentTopPadding - 40);
      });
    }
  });
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance() + .05;
  final second = b.computeLuminance() + .05;
  return first > second ? first / second : second / first;
}
