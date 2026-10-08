import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_highlight_color.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_highlight_quote_background.dart';

void main() {
  final longText = List.filled(30, 'A passage worth remembering.').join(' ');
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  Highlight highlight({
    String? text,
    String? cfi = 'epubcfi(/6/2)',
    SourceType sourceType = SourceType.book,
  }) => Highlight(
    id: 'h',
    sourceId: 'book',
    sourceType: sourceType,
    text: text ?? longText,
    cfiRange: cfi,
    createdAt: DateTime(2026),
  );

  TextStyle spanStyle(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).textSpan!.style!;

  Future<void> pump(
    WidgetTester tester,
    Highlight value, {
    double scale = 1,
    Locale locale = const Locale('en'),
    bool? bookRtl,
    VoidCallback? onNavigate,
    bool dark = false,
    ReaderThemePreset readerTheme = ReaderThemePreset.paper,
    Size size = const Size(320, 568),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var expanded = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ReaderHighlightListTile(
                highlight: value,
                readerTheme: readerTheme.data,
                pageProgressionRtl: bookRtl ?? locale.languageCode == 'ar',
                expanded: expanded,
                onExpanded: () => setState(() => expanded = !expanded),
                onNavigate: onNavigate ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('quote and note rows follow their own content direction', (
    tester,
  ) async {
    await pump(
      tester,
      highlight(text: 'An English quote.').copyWith(note: 'ملاحظة'),
      locale: const Locale('ar'),
      bookRtl: false,
    );
    expect(
      tester.widget<Text>(find.text('An English quote.')).textDirection,
      TextDirection.ltr,
    );
    expect(
      tester.widget<Text>(find.text('ملاحظة')).textDirection,
      TextDirection.rtl,
    );
    // The pencil leads the RTL note even though the book is LTR.
    final noteRow = tester.widget<Row>(
      find.ancestor(of: find.text('ملاحظة'), matching: find.byType(Row)).first,
    );
    expect(noteRow.textDirection, TextDirection.rtl);
    expect(
      tester.getRect(find.byIcon(AppIcons.edit)).left,
      greaterThan(tester.getRect(find.text('ملاحظة')).right),
    );
  });

  testWidgets('page fallback uses the UI language', (tester) async {
    await pump(
      tester,
      highlight(text: 'Quote').copyWith(pageNumber: 42),
      locale: const Locale('ru'),
    );
    final l10n = ReadflexLocalizations.of(tester.element(find.text('Quote')))!;
    expect(find.text(l10n.readerPageNumber(42)), findsOneWidget);
    expect(find.text('Page 42'), findsNothing);
  });

  testWidgets('expands exact text independently of whole-row navigation', (
    tester,
  ) async {
    var navigated = 0;
    await pump(
      tester,
      highlight(),
      onNavigate: () => navigated++,
    );
    expect(tester.widget<Text>(find.text(longText)).maxLines, 3);
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);
    expect(navigated, 0);
    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longText)).maxLines, 3);
    expect(navigated, 0);
    await tester.ensureVisible(find.text(longText));
    await tester.tap(find.text(longText));
    expect(navigated, 1);
  });

  testWidgets(
    'unanchored text remains readable without navigation or actions',
    (
      tester,
    ) async {
      var navigated = 0;
      await pump(
        tester,
        highlight(text: '  Exact text  ', cfi: null),
        onNavigate: () => navigated++,
      );
      expect(find.text('Read more'), findsNothing);
      expect(find.text('Exact text'), findsOneWidget);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byType(AppPlainIconButton), findsNothing);
      await tester.tap(find.text('Exact text'));
      expect(navigated, 0);
      final row = tester.widget<InkWell>(find.byType(InkWell));
      expect(row.onTap, isNull);
    },
  );

  for (final source in SourceType.values) {
    testWidgets('$source quote and location navigate without footer icons', (
      tester,
    ) async {
      var navigated = 0;
      final semantics = tester.ensureSemantics();
      try {
        await pump(
          tester,
          highlight(text: 'A short quote.', sourceType: source).copyWith(
            progress: .25,
            chapterTitle: 'Chapter 1',
            note: 'A note.',
          ),
          onNavigate: () => navigated++,
        );
        for (final icon in [
          AppIcons.copy,
          AppIcons.arrowLeft,
          AppIcons.arrowRight,
        ]) {
          expect(find.byIcon(icon), findsNothing);
        }
        expect(find.text('Read more'), findsNothing);
        expect(
          tester.getSemantics(find.byType(InkWell)),
          matchesSemantics(
            isButton: true,
            hasTapAction: true,
            label: 'A short quote.\nA note.\nChapter 1 · 25%',
            hint: 'Go to passage',
            isFocusable: true,
            hasFocusAction: true,
          ),
        );
        for (final text in ['A short quote.', 'Chapter 1 · 25%', 'A note.']) {
          await tester.tap(find.text(text));
        }
        expect(navigated, 3);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('unanchored long quotes still expand without navigating', (
    tester,
  ) async {
    var navigated = 0;
    await pump(
      tester,
      highlight(cfi: null),
      onNavigate: () => navigated++,
    );
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);
    expect(navigated, 0);
  });

  testWidgets(
    'image-area entry keeps page title and note without text actions',
    (
      tester,
    ) async {
      var navigated = 0;
      final image = highlight(text: 'Page highlight', cfi: null).copyWith(
        kind: HighlightKind.imageArea,
        note: 'My image note',
        chapterTitle: 'The arrival.jpg',
        imageArea: const HighlightImageArea(
          pageIndex: 2,
          x: .1,
          y: .1,
          width: .2,
          height: .2,
        ),
      );
      await pump(
        tester,
        image,
        onNavigate: () => navigated++,
      );
      expect(find.text('My image note'), findsOneWidget);
      // Comic chapter titles are archive file names; the page label leads.
      expect(find.text('The arrival.jpg'), findsNothing);
      expect(find.text('Page 3'), findsOneWidget);
      expect(find.text('Page highlight'), findsNothing);
      expect(find.byIcon(AppIcons.copy), findsNothing);
      expect(find.byIcon(AppIcons.arrowRight), findsNothing);
      expect(find.byIcon(AppIcons.arrowLeft), findsNothing);
      await tester.tap(find.text('Page 3'));
      expect(navigated, 1);
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    final rtl = locale.languageCode == 'ar';
    testWidgets(
      'location starts and Read more ends the footer on the gutters $locale',
      (
        tester,
      ) async {
        await pump(
          tester,
          highlight().copyWith(
            note: 'Short note',
            progress: .25,
            chapterTitle: 'Chapter 1',
          ),
          locale: locale,
        );
        final width = tester.getSize(find.byType(Scaffold)).width;
        double leading(Rect rect) => rtl ? width - rect.right : rect.left;
        double trailing(Rect rect) => rtl ? rect.left : width - rect.right;
        final l10n = tester.element(find.byType(ReaderHighlightListTile)).l10n;
        final quote = tester.getRect(find.text(longText));
        final noteIcon = tester.getRect(find.byIcon(AppIcons.edit));
        final note = tester.getRect(find.text('Short note'));
        final location = tester.getRect(find.text('Chapter 1 · 25%'));
        final label = tester.getRect(find.text(l10n.readerExpandHighlight));
        final button = tester.getRect(find.byType(TextButton));
        // No start rule: the quote sits on the gutter in the book's
        // direction (LTR here) and the English note's mark leads its own
        // LTR row in either UI direction.
        expect(quote.left, AppSpacing.lg);
        expect(width - quote.right, greaterThanOrEqualTo(AppSpacing.lg));
        expect(noteIcon.left, AppSpacing.lg);
        expect(noteIcon.size, const Size.square(AppIconSize.xs));
        expect(note.left, AppSpacing.lg + AppIconSize.xs + AppSpacing.sm);
        expect(width - note.right, greaterThanOrEqualTo(AppSpacing.lg));
        expect(leading(location), AppSpacing.lg);
        // Read more trails the same row: label on the 16dp gutter, ink and
        // 48dp target reaching the drawer edge.
        expect(trailing(label), AppSpacing.lg);
        expect(trailing(button), 0);
        expect(button.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
        expect(
          location.center.dy,
          moreOrLessEquals(button.center.dy, epsilon: 0.5),
        );
        expect(location.top, greaterThan(note.bottom));
        expect(
          find.descendant(
            of: find.byType(TextButton),
            matching: find.byType(AppButtonLabel),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        expect(
          trailing(tester.getRect(find.text(l10n.readerCollapseHighlight))),
          AppSpacing.lg,
        );
        expect(
          leading(tester.getRect(find.text('Chapter 1 · 25%'))),
          AppSpacing.lg,
        );
      },
    );

    testWidgets('image note Read more starts on the note gutter $locale', (
      tester,
    ) async {
      final noteText = List.filled(
        12,
        'A longer comment about this panel.',
      ).join(' ');
      final image = highlight(text: 'Page highlight', cfi: null).copyWith(
        kind: HighlightKind.imageArea,
        note: noteText,
        imageArea: const HighlightImageArea(
          pageIndex: 0,
          x: 0,
          y: 0,
          width: 1,
          height: 1,
        ),
      );
      await pump(tester, image, locale: locale);
      final width = tester.getSize(find.byType(Scaffold)).width;
      double leading(Rect rect) => rtl ? width - rect.right : rect.left;
      double trailing(Rect rect) => rtl ? rect.left : width - rect.right;
      final l10n = tester.element(find.byType(ReaderHighlightListTile)).l10n;
      final note = tester.getRect(find.text(noteText));
      final noteIcon = tester.getRect(find.byIcon(AppIcons.edit));
      final label = tester.getRect(find.text(l10n.readerExpandHighlight));
      final button = tester.getRect(find.byType(TextButton));
      final page = tester.getRect(find.text(l10n.readerPageNumber(1)));
      // The English note keeps an LTR row in both UI directions.
      expect(noteIcon.left, AppSpacing.lg);
      expect(note.left, AppSpacing.lg + AppIconSize.xs + AppSpacing.sm);
      expect(trailing(label), AppSpacing.lg);
      expect(trailing(button), 0);
      expect(button.top, greaterThanOrEqualTo(note.bottom));
      // 96dp preview + 12dp after the 16dp gutter; no start rule.
      expect(leading(page), AppSpacing.lg + 96 + AppSpacing.md);
      expect(
        tester.widget<Text>(find.text(noteText)).style?.fontSize,
        tester.element(find.text(noteText)).text.bodySmall.fontSize,
      );
      expect(
        find.descendant(
          of: find.byType(TextButton),
          matching: find.byType(AppButtonLabel),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('image-area without a note uses a localized page label', (
    tester,
  ) async {
    final image = highlight(text: 'Page highlight', cfi: null).copyWith(
      kind: HighlightKind.imageArea,
      imageArea: const HighlightImageArea(
        pageIndex: 4,
        x: 0,
        y: 0,
        width: .5,
        height: .5,
      ),
    );
    await pump(tester, image, locale: const Locale('ru'));
    final context = tester.element(find.byType(ReaderHighlightListTile));
    expect(find.text(context.l10n.readerPageNumber(5)), findsOneWidget);
    expect(find.text('Page highlight'), findsNothing);
    expect(find.byIcon(AppIcons.copy), findsNothing);
  });

  testWidgets(
    'image notes follow their language, independently of app direction',
    (tester) async {
      for (final sample in [
        ('A quiet afternoon.', TextDirection.ltr, const Locale('ar')),
        (
          '\u0645\u0644\u0627\u062d\u0638\u0629 \u0645\u0647\u0645\u0629.',
          TextDirection.rtl,
          const Locale('en'),
        ),
      ]) {
        final image = highlight(text: 'Page highlight', cfi: null).copyWith(
          kind: HighlightKind.imageArea,
          chapterTitle: 'The arrival.jpg',
          note: sample.$1,
          imageArea: const HighlightImageArea(
            pageIndex: 0,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
          ),
        );
        await pump(tester, image, locale: sample.$3);
        expect(
          tester.widget<Text>(find.text(sample.$1)).textDirection,
          sample.$2,
        );
        expect(find.text('The arrival.jpg'), findsNothing);
      }
    },
  );

  for (final dark in [false, true]) {
    for (final preset in [ReaderThemePreset.paper, ReaderThemePreset.mist]) {
      testWidgets(
        'quote paints the ${preset.id} highlight under its text at 4.5:1 '
        'dark=$dark',
        (tester) async {
          await pump(
            tester,
            highlight(
              text: 'A short quote.',
            ).copyWith(color: HighlightColor.pink, note: 'A note.'),
            dark: dark,
            readerTheme: preset,
          );
          final context = tester.element(find.byType(ReaderHighlightListTile));
          final colors = context.colors;
          final style = spanStyle(tester, 'A short quote.');
          final text = style.color!;
          final background = style.backgroundColor!;
          expect(text, colors.onSurface);
          expect(
            background,
            readerHighlightQuoteBackground(
              highlight: readerHighlightColor(HighlightColor.pink, preset.data),
              surface: colors.surface,
              text: text,
              opacity: readerHighlightOpacity(preset.data),
            ),
          );
          expect(background, isNot(colors.surface));
          expect(
            readerContrastRatio(text, background),
            greaterThanOrEqualTo(readerHighlightQuoteMinContrast),
          );
          // The note is plain text; only the quote carries the colour.
          expect(
            tester.widget<Text>(find.text('A note.')).style?.backgroundColor,
            isNull,
          );
          // The coloured start rule is gone (the divider keeps its border).
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).border
                      is BorderDirectional,
            ),
            findsNothing,
          );
        },
      );
    }
  }

  testWidgets('a removed quote keeps a readable fill under muted text', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ReaderHighlightListTile(
              highlight: highlight(text: 'Gone passage'),
              readerTheme: ReaderThemePreset.paper.data,
              pageProgressionRtl: false,
              expanded: false,
              removed: true,
              onUndo: () {},
              onExpanded: () {},
              onNavigate: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final colors = tester.element(find.byType(Scaffold)).colors;
      final style = spanStyle(tester, 'Gone passage');
      expect(style.color, colors.onSurfaceVariant);
      expect(
        readerContrastRatio(style.color!, style.backgroundColor!),
        greaterThanOrEqualTo(readerHighlightQuoteMinContrast),
        reason: 'dark=$dark',
      );
    }
  });

  testWidgets('the note mark centres on the first bodySmall line', (
    tester,
  ) async {
    await pump(
      tester,
      highlight(text: 'Quote').copyWith(note: longText),
      scale: 1.5,
    );
    final context = tester.element(find.byType(ReaderHighlightListTile));
    final note = tester.widget<Text>(find.text(longText));
    expect(note.style?.fontSize, context.text.bodySmall.fontSize);
    expect(note.maxLines, 2);
    final noteRect = tester.getRect(find.text(longText));
    final icon = tester.getRect(find.byIcon(AppIcons.edit));
    final lineHeight =
        context.text.bodySmall.fontSize! * 1.5 * context.text.bodySmall.height!;
    expect(icon.width, moreOrLessEquals(AppIconSize.xs));
    expect(icon.height, moreOrLessEquals(AppIconSize.xs));
    expect(
      icon.center.dy,
      moreOrLessEquals(noteRect.top + lineHeight / 2, epsilon: 0.5),
    );
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.edit)).color,
      context.colors.onSurfaceVariant,
    );
  });

  testWidgets('rows without a note draw no note mark', (tester) async {
    await pump(tester, highlight(text: 'Quote').copyWith(progress: .5));
    expect(find.byIcon(AppIcons.edit), findsNothing);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('390dp phone keeps the 16dp gutters and 48dp targets $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final rtl = locale.languageCode == 'ar';
      await pump(
        tester,
        highlight().copyWith(
          note: 'Note',
          progress: .4,
          chapterTitle: 'Chapter',
        ),
        locale: locale,
        size: const Size(390, 844),
      );
      final l10n = tester.element(find.byType(ReaderHighlightListTile)).l10n;
      final quote = tester.getRect(find.text(longText));
      final location = tester.getRect(find.text('Chapter · 40%'));
      final label = tester.getRect(find.text(l10n.readerExpandHighlight));
      // The book is RTL in the Arabic UI here, so the quote mirrors with it.
      expect(rtl ? 390 - quote.right : quote.left, AppSpacing.lg);
      expect(rtl ? quote.left : 390 - quote.right, greaterThanOrEqualTo(16));
      expect(rtl ? 390 - location.right : location.left, AppSpacing.lg);
      expect(rtl ? label.left : 390 - label.right, AppSpacing.lg);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(AppSizes.buttonHeight),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('a long location at 2x shares the row without overflowing', (
    tester,
  ) async {
    await pump(
      tester,
      highlight().copyWith(
        progress: .4,
        chapterTitle: 'A chapter title long enough to wrap in a narrow drawer',
      ),
      scale: 2,
      locale: const Locale('de'),
    );
    expect(tester.takeException(), isNull);
    final width = tester.getSize(find.byType(Scaffold)).width;
    final location = tester.getRect(
      find.textContaining('A chapter title long enough'),
    );
    final button = tester.getRect(find.byType(TextButton));
    expect(location.left, AppSpacing.lg);
    expect(location.right, lessThanOrEqualTo(button.left));
    expect(button.right, width);
    expect(button.width, lessThanOrEqualTo(width / 2));
    expect(button.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
  });

  group('removed rows', () {
    Future<void> pumpRemoved(
      WidgetTester tester,
      Highlight value, {
      bool failed = false,
      VoidCallback? onUndo,
      VoidCallback? onNavigate,
    }) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReaderHighlightListTile(
                highlight: value,
                readerTheme: ReaderThemePreset.paper.data,
                pageProgressionRtl: false,
                expanded: false,
                removed: true,
                failed: failed,
                onUndo: onUndo,
                onExpanded: () => fail('removed rows do not expand'),
                onNavigate: onNavigate ?? () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('text row keeps its quote muted with an icon-only Undo', (
      tester,
    ) async {
      var undone = 0;
      var navigated = 0;
      await pumpRemoved(
        tester,
        highlight(text: 'Gone passage').copyWith(progress: .4),
        onUndo: () => undone++,
        onNavigate: () => navigated++,
      );
      final context = tester.element(find.byType(ReaderHighlightListTile));
      final l10n = context.l10n;
      final colors = context.colors;
      expect(find.text(l10n.readerHighlightRemoved), findsOneWidget);
      expect(find.text('40%'), findsNothing);
      expect(find.text(l10n.readerExpandHighlight), findsNothing);
      expect(
        tester.widget<Text>(find.text('Gone passage')).textSpan?.style?.color,
        colors.onSurfaceVariant,
      );
      final undo = find.byTooltip(l10n.commonUndo);
      expect(undo, findsOneWidget);
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.getSize(undo), const Size.square(AppSizes.buttonHeight));
      // Glyph edge on the 16dp content gutter, like the bookmark rows.
      final width = tester.getSize(find.byType(Scaffold)).width;
      expect(
        width - tester.getRect(find.byIcon(AppIcons.undo)).right,
        AppSpacing.lg,
      );
      await tester.tap(find.text('Gone passage'));
      expect(navigated, 0);
      await tester.tap(undo);
      expect(undone, 1);
    });

    testWidgets('a busy row disables only its Undo', (tester) async {
      await pumpRemoved(tester, highlight(text: 'Gone passage'));
      final l10n = tester.element(find.byType(ReaderHighlightListTile)).l10n;
      expect(
        tester
            .widget<AppPlainIconButton>(find.byType(AppPlainIconButton))
            .onPressed,
        isNull,
      );
      expect(find.byTooltip(l10n.commonUndo), findsOneWidget);
    });

    testWidgets('restore failure stays on the row with Undo', (tester) async {
      await pumpRemoved(
        tester,
        highlight(text: 'Gone passage'),
        failed: true,
        onUndo: () {},
      );
      final l10n = tester.element(find.byType(ReaderHighlightListTile)).l10n;
      expect(
        find.text(
          '${l10n.readerHighlightRemoved} · ${l10n.readerHighlightSaveFailed}',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
    });

    testWidgets('image row shows the page label, status and Undo', (
      tester,
    ) async {
      var undone = 0;
      var navigated = 0;
      await pumpRemoved(
        tester,
        highlight(text: 'Page highlight', cfi: null).copyWith(
          kind: HighlightKind.imageArea,
          note: 'Image note',
          imageArea: const HighlightImageArea(
            pageIndex: 2,
            x: .1,
            y: .1,
            width: .2,
            height: .2,
          ),
        ),
        onUndo: () => undone++,
        onNavigate: () => navigated++,
      );
      final context = tester.element(find.byType(ReaderHighlightListTile));
      final l10n = context.l10n;
      expect(find.text(l10n.readerPageNumber(3)), findsOneWidget);
      expect(find.text(l10n.readerHighlightRemoved), findsOneWidget);
      expect(find.text('Image note'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text(l10n.readerPageNumber(3)))
            .textSpan
            ?.style
            ?.color,
        context.colors.onSurfaceVariant,
      );
      await tester.tap(find.text(l10n.readerPageNumber(3)));
      expect(navigated, 0);
      await tester.tap(find.byTooltip(l10n.commonUndo));
      expect(undone, 1);
    });
  });

  for (final locale in [
    const Locale('en'),
    const Locale('de'),
    const Locale('ar'),
  ]) {
    testWidgets('image note expands without navigating at 2x in $locale', (
      tester,
    ) async {
      var navigated = 0;
      final image = highlight(text: 'Page highlight', cfi: null).copyWith(
        kind: HighlightKind.imageArea,
        chapterTitle:
            'A long page title that must wrap inside a narrow drawer.jpg',
        note: longText,
        imageArea: const HighlightImageArea(
          pageIndex: 1,
          x: .2,
          y: .1,
          width: .5,
          height: .2,
        ),
      );
      await pump(
        tester,
        image,
        scale: 2,
        locale: locale,
        onNavigate: () => navigated++,
      );
      final context = tester.element(find.byType(ReaderHighlightListTile));
      expect(tester.widget<Text>(find.text(longText)).maxLines, 3);
      await tester.ensureVisible(find.text(context.l10n.readerExpandHighlight));
      await tester.tap(find.text(context.l10n.readerExpandHighlight));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);
      expect(navigated, 0);
      expect(find.byTooltip(context.l10n.commonCopy), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text(context.l10n.readerCollapseHighlight),
      );
      await tester.tap(find.text(context.l10n.readerCollapseHighlight));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(longText)).maxLines, 3);
    });

    testWidgets('long notes and actions fit at 2x on a narrow $locale phone', (
      tester,
    ) async {
      await pump(
        tester,
        highlight().copyWith(note: longText),
        scale: 2,
        locale: locale,
      );
      final context = tester.element(find.byType(ReaderHighlightListTile));
      await tester.ensureVisible(find.text(context.l10n.readerExpandHighlight));
      await tester.tap(find.text(context.l10n.readerExpandHighlight));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(longText).first).maxLines, isNull);
      expect(find.byType(AppPlainIconButton), findsNothing);
      await tester.ensureVisible(
        find.text(context.l10n.readerCollapseHighlight),
      );
      await tester.tap(find.text(context.l10n.readerCollapseHighlight));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(longText).first).maxLines, 3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'an image entry with a missing area does not offer text actions',
    (tester) async {
      var navigated = 0;
      await pump(
        tester,
        highlight(
          text: 'Page highlight',
          cfi: null,
        ).copyWith(kind: HighlightKind.imageArea),
        onNavigate: () => navigated++,
      );
      final context = tester.element(find.byType(ReaderHighlightListTile));
      await tester.tap(find.text(context.l10n.readerLocationUnavailable));
      expect(navigated, 0);
      expect(find.byIcon(AppIcons.copy), findsNothing);
      expect(find.text('Page highlight'), findsNothing);
    },
  );
}
