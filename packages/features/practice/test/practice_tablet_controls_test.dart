import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/practice_item.dart';
import 'package:practice/src/practice_source_summary.dart';
import 'package:practice/src/review_interval_label.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in const [
      ('Geist', 'Geist-Variable.ttf'),
      ('Literata', 'Literata-Variable.ttf'),
      ('Noto Sans Symbols', 'NotoSansSymbols-Regular.ttf'),
    ]) {
      await (FontLoader(family)..addFont(
            rootBundle.load('packages/component_library/fonts/$file'),
          ))
          .load();
    }
    var root = Directory.current;
    while (!File('${root.path}/test/fonts/NotoSansArabic.ttf').existsSync()) {
      final parent = root.parent;
      if (parent.path == root.path) throw StateError('Test fonts not found');
      root = parent;
    }
    for (final family in const [
      'Noto Sans Arabic',
      'Noto Sans Devanagari',
      'Noto Sans JP',
      'Noto Sans SC',
    ]) {
      final bytes = await File(
        '${root.path}/test/fonts/${family.replaceAll(' ', '')}.ttf',
      ).readAsBytes();
      await (FontLoader(family)..addFont(
            Future.value(ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });

  for (final (size, scale, locale, medium) in [
    (const Size(390, 844), 1.0, const Locale('en'), false),
    (const Size(844, 390), 1.0, const Locale('en'), false),
    (const Size(800, 1280), 1.0, const Locale('en'), true),
    (const Size(1280, 800), 1.0, const Locale('en'), true),
    for (final locale in ReadflexSupportedLocales.locales)
      for (final size in const [Size(800, 1280), Size(1280, 800)])
        (size, 2.0, locale, true),
  ]) {
    testWidgets('Practice control roles and actions $size $locale ${scale}x', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        Future<void> mount(Widget child) async {
          await tester.pumpWidget(
            _PracticeControlsApp(locale: locale, scale: scale, child: child),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        var sourceOpened = 0;
        const sourceId = 'long-saved-book';
        final source = LibrarySource.fromBook(
          Book(
            id: sourceId,
            title: List.filled(6, 'A long saved book title').join(' '),
            filePath: 'fixture.epub',
            format: BookFormat.epub,
            addedAt: DateTime(2026),
          ),
        );
        await mount(
          AppContentFrame(
            maxWidth: 720,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const PracticeTodayCard(
                    due: 123456,
                    dueWords: 123450,
                    dueHighlights: 6,
                    newToday: 7,
                    streakDays: 365,
                    reviewedLast7Days: 12345,
                    total: 123456,
                  ),
                  PracticeSourceRow(
                    key: const ValueKey('tabletControlSource'),
                    summary: PracticeSourceSummary(
                      source: source,
                      words: 123450,
                      highlights: 6,
                      due: 123456,
                    ),
                    onPressed: () => sourceOpened++,
                  ),
                ],
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(PracticeTodayCard));
        final l10n = ReadflexLocalizations.of(context)!;
        final text = context.text;
        final dueSize = medium
            ? text.bodyMedium.fontSize
            : text.bodySmall.fontSize;
        expect(
          tester
              .widget<Text>(find.text(l10n.practiceTodayTitle))
              .style!
              .fontSize,
          medium ? text.labelLarge.fontSize : text.labelMedium.fontSize,
        );
        for (final label in [
          l10n.practiceWordCount(123450),
          l10n.practiceHighlightCount(6),
          l10n.practiceNewToday(7),
        ]) {
          final finder = find.descendant(
            of: find.byType(PracticeTodayCard),
            matching: find.text(label),
          );
          expect(tester.widget<Text>(finder).style!.fontSize, dueSize);
          _expectTextFits(tester, finder);
        }
        expect(
          tester
              .widget<Text>(find.text(l10n.practiceThisWeek(12345)))
              .style!
              .fontSize,
          text.bodySmall.fontSize,
        );
        final due = find.byKey(const ValueKey('practiceSourceDue-$sourceId'));
        expect(
          tester.widget<Text>(due).style!.fontSize,
          medium ? text.labelLarge.fontSize : text.labelMedium.fontSize,
        );
        final row = find.byKey(const ValueKey('tabletControlSource'));
        _expectTextFits(tester, due);
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final sourceRect = tester.getRect(row);
        _expectTargetFits(sourceRect, size);
        await tester.tapAt(sourceRect.center);
        final sourceNode = tester.getSemantics(row);
        expect(sourceNode.label, source.title);
        expect(
          sourceNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(sourceNode.rect.width, closeTo(sourceRect.width, .01));
        expect(sourceNode.rect.height, closeTo(sourceRect.height, .01));
        sourceNode.owner!.performAction(sourceNode.id, SemanticsAction.tap);
        expect(sourceOpened, 2);

        const intervals = {
          Rating.again: Duration(minutes: 10),
          Rating.hard: Duration(days: 8),
          Rating.good: Duration(days: 3650000),
          Rating.easy: Duration(days: 36500),
        };
        final items = <PracticeItem>[
          PracticeWordItem(
            entry: DictionaryEntry(
              id: 'word',
              word: 'reading',
              translation: 'A saved meaning',
              addedAt: DateTime(2026),
            ),
            fsrs: const FsrsCardData(),
          ),
          PracticeHighlightItem(
            highlight: Highlight(
              id: 'highlight',
              sourceId: sourceId,
              sourceType: SourceType.book,
              text: 'A saved passage.',
              createdAt: DateTime(2026),
            ),
            fsrs: const FsrsCardData(),
          ),
        ];
        for (final item in items) {
          final rated = <Rating>[];
          var opened = 0;
          await mount(
            Column(
              children: [
                ReviewSessionTopBar(
                  position: 1,
                  total: 12345,
                  canOpenInSource: false,
                  onClose: () {},
                  onOpenInSource: () {},
                  onRemove: () {},
                ),
                const Spacer(),
                ReviewSessionControls(
                  item: item,
                  revealed: true,
                  intervals: intervals,
                  onReveal: () {},
                  onRated: rated.add,
                  onOpenInSource: item is PracticeHighlightItem
                      ? () => opened++
                      : null,
                ),
              ],
            ),
          );
          final position = find.byKey(const ValueKey('reviewPosition'));
          expect(
            tester.widget<Text>(position).style!.fontSize,
            medium ? text.labelLarge.fontSize : text.screenCounter.fontSize,
          );
          _expectTextFits(tester, position);
          final ratings = item is PracticeWordItem
              ? const [
                  ('again', Rating.again),
                  ('hard', Rating.hard),
                  ('good', Rating.good),
                ]
              : const [('keep', Rating.good), ('showLess', Rating.easy)];
          for (final (name, rating) in ratings) {
            final control = find.byKey(ValueKey('reviewRate-$name'));
            final interval = reviewIntervalLabel(l10n, intervals[rating]!);
            final caption = find.descendant(
              of: control,
              matching: find.text(interval),
            );
            expect(
              tester.widget<Text>(caption).style!.fontSize,
              medium ? text.labelLarge.fontSize : text.labelSmall.fontSize,
            );
            final rect = tester.getRect(control);
            _expectTextFits(tester, caption);
            _expectTargetFits(rect, size);
            final node = tester.getSemantics(control);
            expect(node.value, interval);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            expect(node.rect.width, closeTo(rect.width, .01));
            expect(node.rect.height, closeTo(rect.height, .01));
            await tester.tapAt(rect.center);
            node.owner!.performAction(node.id, SemanticsAction.tap);
          }
          expect(rated, [
            for (final (_, rating) in ratings) ...[rating, rating],
          ]);
          if (item is PracticeHighlightItem) {
            await tester.tap(find.byKey(const ValueKey('reviewOpenInBook')));
            expect(opened, 1);
          }
          expect(tester.takeException(), isNull);
        }

        var completed = 0;
        await mount(
          ReviewSessionSummary(
            reviewed: 123456,
            known: 123456,
            again: 0,
            onDone: () => completed++,
            onReviewAgain: () {},
          ),
        );
        final counts = find.byKey(const ValueKey('reviewSummaryCounts'));
        expect(
          tester.widget<Text>(counts).style!.fontSize,
          text.bodyMedium.fontSize,
        );
        _expectTextFits(tester, counts);
        final done = find.byKey(const ValueKey('reviewDone'));
        await tester.ensureVisible(done);
        await tester.pumpAndSettle();
        _expectTargetFits(tester.getRect(done), size);
        await tester.tap(done);
        expect(completed, 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

void _expectTextFits(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  final text = tester.widget<Text>(finder);
  expect(text.maxLines, isNull);
  expect(text.overflow, isNot(TextOverflow.ellipsis));
  // RenderParagraph clips allocated text overflow. Selection boxes include
  // font metrics and trailing whitespace; they do not describe painted ink.
  expect(
    paragraph.textSize.width,
    lessThanOrEqualTo(paragraph.size.width + .01),
  );
  expect(
    paragraph.textSize.height,
    lessThanOrEqualTo(paragraph.size.height + .01),
  );
}

void _expectTargetFits(Rect target, Size window) {
  expect(target.width, greaterThanOrEqualTo(48));
  expect(target.height, greaterThanOrEqualTo(48));
  expect(target.left, greaterThanOrEqualTo(0));
  expect(target.top, greaterThanOrEqualTo(0));
  expect(target.right, lessThanOrEqualTo(window.width));
  expect(target.bottom, lessThanOrEqualTo(window.height));
}

class _PracticeControlsApp extends StatelessWidget {
  const _PracticeControlsApp({
    required this.locale,
    required this.scale,
    required this.child,
  });

  final Locale locale;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}
