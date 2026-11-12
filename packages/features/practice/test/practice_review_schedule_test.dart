import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/practice_item.dart';
import 'package:practice/src/practice_word_sheet.dart';
import 'package:practice/src/review_due_label.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const _longSource =
    'A Reader’s Companion to Stories, Language, Memory and the Art of Learning';
final _deadline = DateTime(2026, 11, 7, 14, 35).toUtc();
final _scheduled = FsrsCardData(
  state: FsrsState.review,
  nextReviewAt: _deadline,
  reps: 1,
);

PracticeWordItem _word(FsrsCardData fsrs) => PracticeWordItem(
  entry: DictionaryEntry(
    id: 'scheduled-word',
    word: 'reading',
    translation: 'чтение',
    addedAt: DateTime(2026),
    sourceId: 'book',
    sourceType: SourceType.book,
  ),
  fsrs: fsrs,
  sourceTitle: _longSource,
);

PracticeHighlightItem _highlight(FsrsCardData fsrs) => PracticeHighlightItem(
  highlight: Highlight(
    id: 'scheduled-highlight',
    sourceId: 'book',
    sourceType: SourceType.book,
    text: 'Reading is a quiet conversation with the page.',
    chapterTitle: _longSource,
    createdAt: DateTime(2026),
  ),
  fsrs: fsrs,
  sourceTitle: _longSource,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
    double width = 390,
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (locale, width, scale, dark) in [
    (const Locale('en'), 390.0, 1.0, false),
    (const Locale('ru'), 390.0, 1.0, true),
    (const Locale('de'), 320.0, 2.0, false),
    (const Locale('ar'), 320.0, 2.0, true),
  ]) {
    for (final highlight in [false, true]) {
      testWidgets('full deadline stays visible with a long source: '
          '$locale ${width}dp ${scale}x highlight=$highlight', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final row = highlight
              ? PracticeHighlightRow(
                  item: _highlight(_scheduled),
                  onPressed: () {},
                )
              : PracticeWordRow(word: _word(_scheduled), onPressed: () {});
          await pump(
            tester,
            row,
            locale: locale,
            width: width,
            scale: scale,
            dark: dark,
          );
          final rowFinder = find.byWidget(row);
          final context = tester.element(rowFinder);
          final label = reviewDueLabel(context, _scheduled);
          final deadline = find.descendant(
            of: rowFinder,
            matching: find.text(label),
          );
          expect(deadline, findsOneWidget);
          expect(tester.getSemantics(rowFinder).value, contains(label));
          final text = tester.widget<Text>(deadline);
          final paragraph = tester.renderObject<RenderParagraph>(deadline);
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(text.style!.color, context.colors.onSurfaceVariant);
          expect(text.style!.fontSize, context.text.bodySmall.fontSize);
          final source = find.descendant(
            of: rowFinder,
            matching: find.text(_longSource),
          );
          expect(
            tester.getTopLeft(deadline).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(source).dy - .01),
          );
          final bounds = tester.getRect(deadline);
          expect(bounds.left, greaterThanOrEqualTo(16 - .01));
          expect(bounds.right, lessThanOrEqualTo(width - 16 + .01));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }

  testWidgets('new cards do not invent a next-review date', (tester) async {
    for (final row in [
      PracticeWordRow(word: _word(const FsrsCardData()), onPressed: () {}),
      PracticeHighlightRow(
        item: _highlight(const FsrsCardData()),
        onPressed: () {},
      ),
    ]) {
      await pump(tester, row);
      final strings = tester.element(find.byWidget(row)).l10n;
      expect(find.text(strings.practiceDueNew), findsOneWidget);
      expect(find.textContaining('2026'), findsNothing);
    }
  });

  testWidgets(
    'word details show the same stored deadline above pinned actions',
    (
      tester,
    ) async {
      final word = _word(_scheduled);
      await pump(tester, PracticeWordRow(word: word, onPressed: () {}));
      final label = reviewDueLabel(
        tester.element(find.byType(PracticeWordRow)),
        word.fsrs,
      );
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPracticeWordSheet(
              context,
              word: word,
              canOpenInSource: true,
            ),
            child: const Text('Open details'),
          ),
        ),
      );
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      final deadline = find.descendant(
        of: find.byType(PracticeWordSheet),
        matching: find.text(label),
      );
      await tester.ensureVisible(deadline);
      await tester.pumpAndSettle();
      expect(deadline.hitTestable(), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(deadline).didExceedMaxLines,
        isFalse,
      );
      expect(
        tester.getBottomLeft(deadline).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(AppSheetActions)).dy + .01,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
