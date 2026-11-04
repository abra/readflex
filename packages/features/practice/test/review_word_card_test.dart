import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';

import 'helpers/practice_harness.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(AppTypography.fontFamilySerif)..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Literata-Variable.ttf',
          ),
        ))
        .load();
  });

  testWidgets('320dp at 200% keeps the headword whole above the title floor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = (await tester.runAsync(PracticeHarness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(
      () => harness.addWord(
        'reading',
        translation: 'чтение',
        context: 'Reading is a quiet conversation with the page.',
      ),
    );
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

    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      for (final revealed in [false, true]) {
        if (revealed) {
          await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
          await tester.pumpAndSettle();
        }
        final headword = find.byKey(const ValueKey('reviewWord'));
        final context = tester.element(headword);
        final text = tester.widget<Text>(headword);
        final paragraph = tester.renderObject<RenderParagraph>(headword);
        expect(text.data, 'reading');
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
        expect(
          text.style!.fontSize,
          greaterThanOrEqualTo(context.text.titleLarge.fontSize!),
        );
        expect(
          text.style!.fontSize,
          lessThan(context.text.displaySmall.fontSize!),
        );
        expect(
          paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 7),
          ),
          hasLength(1),
          reason:
              'A single headword must occupy one line with the shipped font.',
        );
        expect(tester.getSemantics(headword).label, 'reading');
        final sentence = tester.renderObject<RenderParagraph>(
          find.byKey(const ValueKey('reviewSentence')),
        );
        final bodySize = context.text.bodyLarge.fontSize!;
        expect(sentence.textScaler.scale(bodySize), bodySize * 2);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('revealing a long word card preserves its reading position', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(PracticeHarness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(
      () => harness.addWord(
        'reading',
        translation: 'чтение',
        context: List.filled(
          30,
          'Reading is a quiet conversation with the page.',
        ).join('\n\n'),
      ),
    );
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
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('reviewCardViewport')),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    final readingOffset = position.pixels;
    expect(find.byKey(const ValueKey('reviewAnswer')), findsNothing);
    expect(find.byKey(const ValueKey('reviewRate-good')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reviewShowAnswer')));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scrollable).position, same(position));
    expect(position.pixels, readingOffset);
    expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
    expect(find.byKey(const ValueKey('reviewAnswer')), findsOneWidget);
    for (final id in ['again', 'hard', 'good']) {
      final rating = find.byKey(ValueKey('reviewRate-$id'));
      expect(rating.hitTestable(), findsOneWidget);
      expect(tester.getSize(rating).height, greaterThanOrEqualTo(48));
    }
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reviewAnswer')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
