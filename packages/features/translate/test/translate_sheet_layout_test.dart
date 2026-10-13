import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import 'helpers/translate_sheet_harness.dart';

/// The translation sheet's sections, spacing, Copy placement and text
/// fitting.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('layout', () {
    final expressionService = WordTranslationService(
      const ContextualTranslationText(
        baseTranslation: 'удача; судьба',
        sentenceTranslation: 'Холостяк с солидным состоянием ищет жену.',
      ),
      analysis: const ContextualTranslationAnalysis(
        surfaceForm: 'fortune',
        lemma: 'fortunes',
        pronunciation: '/ˈfɔːtʃuːn/',
        partOfSpeech: 'noun',
        expressionType: 'word',
      ),
      expression: const ContextualTranslationExpression(
        text: 'good fortune',
        translation: 'солидное состояние',
      ),
      explanation: 'Wealth, not luck.',
    );
    const fortune = TextSelectionContext(
      selectedText: 'fortune',
      contextText: 'A man in possession of a good fortune must want a wife.',
      markedContextText:
          'A man in possession of a good [[fortune]] must want a wife.',
      sourceId: 'source-1',
      sourceType: SourceType.book,
      sourceLanguageHint: 'en',
    );
    final primary = find.byKey(const ValueKey('translation-primary-result'));
    final base = find.byKey(const ValueKey('translation-base-result'));
    final expression = find.byKey(
      const ValueKey('translation-contextual-expression'),
    );
    final sections = find.byType(AppSheetSection);
    Rect outline(WidgetTester tester, int index) =>
        sectionOutline(tester, sections.at(index));

    testWidgets('the selection is a quiet label; the answer is the heading', (
      tester,
    ) async {
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
      );
      final theme = Theme.of(tester.element(primary));
      expect(
        tester.widget<SelectableText>(selectedFragmentFinder).style,
        theme.textTheme.titleMedium!.copyWith(
          letterSpacing: 0,
          color: theme.colorScheme.onSurface,
        ),
      );
      expect(
        tester.widget<SelectableText>(primary).style,
        theme.textTheme.headlineSmall!.copyWith(letterSpacing: 0),
      );
      expect(
        tester.widget<SelectableText>(expression).style,
        theme.textTheme.titleMedium!.copyWith(
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      );
      expect(
        tester.widget<SelectableText>(base).style,
        theme.textTheme.bodyLarge!.copyWith(letterSpacing: 0),
      );
    });

    testWidgets('pronunciation follows the word; grammar and base form are '
        'on the line below', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
      );
      final word = tester.getRect(selectedFragmentFinder);
      final ipa = tester.getRect(find.text('/ˈfɔːtʃuːn/'));
      final noun = tester.getRect(find.text('Noun'));
      final baseForm = tester.getRect(baseFormFinder);
      expect(ipa.left, greaterThan(word.right));
      expect(ipa.center.dy, moreOrLessEquals(word.center.dy, epsilon: 1));
      expect(noun.left, word.left);
      expect(noun.top, greaterThanOrEqualTo(word.bottom));
      expect(baseForm.left, greaterThan(noun.right));
      expect(baseForm.top, noun.top);
    });

    final grammarExamples = [
      (
        direction: TextDirection.ltr,
        selection: fortune,
        service: expressionService,
        partOfSpeech: 'Noun',
      ),
      (
        direction: TextDirection.rtl,
        selection: const TextSelectionContext(
          selectedText: 'كتب',
          sourceId: 'source-1',
          sourceType: SourceType.book,
        ),
        service: WordTranslationService(
          const ContextualTranslationText(baseTranslation: 'написал'),
          analysis: const ContextualTranslationAnalysis(
            surfaceForm: 'كتب',
            lemma: 'كتابة',
            partOfSpeech: 'verb',
          ),
        ),
        partOfSpeech: 'Verb',
      ),
    ];

    for (final example in grammarExamples) {
      testWidgets(
        '${example.direction.name} grammar line starts on the word edge and '
        'reads in its order',
        (tester) async {
          await pumpTranslateSheet(
            tester,
            selection: example.selection,
            service: example.service,
          );
          final word = tester.getRect(selectedFragmentFinder);
          final partOfSpeech = tester.getRect(find.text(example.partOfSpeech));
          final dot = tester.getRect(find.text(' · '));
          final baseForm = tester.getRect(baseFormFinder);
          if (example.direction == TextDirection.ltr) {
            expect(partOfSpeech.left, word.left);
            expect(dot.left, moreOrLessEquals(partOfSpeech.right));
            expect(baseForm.left, moreOrLessEquals(dot.right));
          } else {
            expect(partOfSpeech.right, word.right);
            expect(dot.right, moreOrLessEquals(partOfSpeech.left));
            expect(baseForm.right, moreOrLessEquals(dot.left));
          }
          expect(baseForm.top, partOfSpeech.top);
        },
      );

      testWidgets(
        '${example.direction.name} base form that does not fit the line moves '
        'below the part of speech, without the dot',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          // Test glyphs are squares: the part of speech, the dot and the base
          // form are over 300dp together, wider than the 272dp line.
          await pumpTranslateSheet(
            tester,
            selection: example.selection,
            service: example.service,
          );
          expect(find.text(' · '), findsNothing);
          final partOfSpeech = tester.getRect(find.text(example.partOfSpeech));
          final baseForm = tester.getRect(baseFormFinder);
          expect(baseForm.top - partOfSpeech.bottom, AppSpacing.xxs);
          if (example.direction == TextDirection.ltr) {
            expect(baseForm.left, partOfSpeech.left);
          } else {
            expect(baseForm.right, partOfSpeech.right);
          }
          // Its own wrapped lines keep that edge too.
          expect(
            tester.widget<Text>(baseFormFinder).textAlign,
            example.direction == TextDirection.ltr
                ? TextAlign.left
                : TextAlign.right,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final example in [
      (
        name: 'part of speech',
        analysis: const ContextualTranslationAnalysis(
          surfaceForm: 'fortune',
          partOfSpeech: 'noun',
        ),
        shown: find.text('Noun'),
      ),
      (
        name: 'base form',
        analysis: const ContextualTranslationAnalysis(
          surfaceForm: 'fortune',
          lemma: 'fortunes',
        ),
        shown: baseFormFinder,
      ),
    ]) {
      testWidgets('${example.name} alone has no dot', (tester) async {
        await pumpTranslateSheet(
          tester,
          selection: fortune,
          service: WordTranslationService(
            const ContextualTranslationText(baseTranslation: 'удача'),
            analysis: example.analysis,
          ),
        );
        expect(example.shown, findsOneWidget);
        expect(find.text(' · '), findsNothing);
      });
    }

    testWidgets('the dot is not announced', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
      );
      expect(find.text(' · '), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('·')), findsNothing);
      expect(find.bySemanticsLabel('Noun'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Base form: .fortunes.\$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final example in [
      (locale: const Locale('en'), word: 'كتب', lemma: 'كتابة'),
      (locale: const Locale('ar'), word: 'strongest', lemma: 'strong'),
    ]) {
      testWidgets('the base form label precedes ${example.lemma} in the '
          '${example.locale} reading order', (tester) async {
        await pumpTranslateSheet(
          tester,
          locale: example.locale,
          selection: TextSelectionContext(
            selectedText: example.word,
            sourceId: 'source-1',
            sourceType: SourceType.book,
          ),
          service: WordTranslationService(
            const ContextualTranslationText(baseTranslation: 'перевод'),
            analysis: ContextualTranslationAnalysis(
              surfaceForm: example.word,
              lemma: example.lemma,
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: baseFormFinder, matching: find.byType(RichText)),
        );
        final text = baseFormText(tester);
        final lemmaStart = text.indexOf(example.lemma);
        Rect span(int start, int end) => paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: end),
            )
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b));
        // Everything before the lemma's isolate is the label.
        final label = span(0, lemmaStart - 1);
        final lemma = span(lemmaStart, lemmaStart + example.lemma.length);
        if (example.locale.languageCode == 'en') {
          expect(lemma.left, greaterThanOrEqualTo(label.right - 0.5));
        } else {
          expect(lemma.right, lessThanOrEqualTo(label.left + 0.5));
        }
      });
    }

    testWidgets('each answer, the sentence and the details are outlined '
        'sections in reading order', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
      );
      expect(sections, findsNWidgets(4));
      final contents = [
        primary,
        base,
        previewFinder,
        find.text('Meaning & alternatives'),
      ];
      for (var i = 0; i < contents.length; i++) {
        expect(
          find.descendant(of: sections.at(i), matching: contents[i]),
          findsOneWidget,
          reason: 'section $i',
        );
      }
      expect(find.byType(AppSourceQuote), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('text translation has the answer and the original sections', (
      tester,
    ) async {
      await pumpTranslateSheet(tester, selection: paragraphSelection);
      expect(sections, findsNWidgets(2));
      expect(
        find.descendant(of: sections.first, matching: primary),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sections.last, matching: find.text('Original')),
        findsOneWidget,
      );
      expect(selectedFragmentFinder, findsNothing);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('sections are 12dp apart with 12dp inside at ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpTranslateSheet(
          tester,
          selection: fortune,
          service: expressionService,
          textScaler: TextScaler.linear(scale),
        );
        final boxes = [for (var i = 0; i < 4; i++) outline(tester, i)];
        for (var i = 1; i < boxes.length; i++) {
          expect(boxes[i].top - boxes[i - 1].bottom, AppSpacing.md);
        }
        final subjectBottom = tester
            .getRect(find.byKey(const ValueKey('translation-lexical-header')))
            .bottom;
        expect(
          boxes.first.top - subjectBottom,
          AppSpacing.lg,
          reason: 'the selection sits 16dp above the first section',
        );
        double top(Finder finder, int box) =>
            tester.getRect(finder).top - boxes[box].top;
        double bottom(Finder finder, int box) =>
            boxes[box].bottom - tester.getRect(finder).bottom;
        expect(top(find.text('In this context'), 0), AppSpacing.md);
        expect(bottom(primary, 0), AppSpacing.md);
        expect(top(find.text('Word meaning'), 1), AppSpacing.md);
        expect(bottom(base, 1), AppSpacing.md);
        expect(top(find.text('Sentence'), 2), AppSpacing.md);
        expect(
          bottom(find.byKey(const ValueKey('translation-sentence-result')), 2),
          AppSpacing.md,
        );
      });
    }

    testWidgets('titles sit 8dp above their content, the expression 4dp '
        'above its answer', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
      );
      double gap(Finder above, Finder below) =>
          tester.getRect(below).top - tester.getRect(above).bottom;
      expect(gap(find.text('In this context'), expression), AppSpacing.sm);
      expect(gap(expression, primary), AppSpacing.xs);
      expect(gap(find.text('Word meaning'), base), AppSpacing.sm);
      expect(gap(find.text('Sentence'), previewFinder), AppSpacing.sm);
      expect(
        gap(
          previewFinder,
          find.byKey(const ValueKey('translation-sentence-result')),
        ),
        AppSpacing.sm,
      );
    });

    testWidgets('an answer without a title has 12dp inside its section', (
      tester,
    ) async {
      await pumpTranslateSheet(tester, selection: powerSelection);
      final box = outline(tester, 0);
      expect(tester.getRect(primary).top - box.top, AppSpacing.md);
      expect(box.bottom - tester.getRect(primary).bottom, AppSpacing.md);
    });

    testWidgets('each Copy is centered on its answer and reaches the outline', (
      tester,
    ) async {
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
      );
      for (final (index, id) in ['primary', 'base'].indexed) {
        final result = find.byKey(ValueKey('translation-$id-result'));
        final style = tester.widget<SelectableText>(result).style!;
        final line = style.fontSize! * style.height!;
        final copy = tester.getRect(
          find.byKey(ValueKey('translation-$id-copy')),
        );
        expect(
          copy.center.dy,
          moreOrLessEquals(tester.getRect(result).top + line / 2),
          reason: id,
        );
        expect(copy.width, moreOrLessEquals(48), reason: id);
        expect(copy.height, moreOrLessEquals(48), reason: id);
        expect(copy.right, outline(tester, index).right, reason: id);
      }
    });

    testWidgets('titles keep the interface edge; LTR content keeps its own '
        'in an Arabic UI', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: fortune,
        service: expressionService,
        locale: const Locale('ar'),
      );
      final l10n = ReadflexLocalizations.of(
        tester.element(find.byType(TranslateSheet)),
      )!;
      final sheet = tester.getRect(find.byType(TranslateSheet));
      for (final title in [
        l10n.translationInContext,
        l10n.translationWordMeaning,
        l10n.translationSentence,
      ]) {
        expect(
          sheet.right - tester.getRect(find.text(title)).right,
          AppSpacing.xl,
          reason: title,
        );
      }
      for (final content in [
        selectedFragmentFinder,
        expression,
        primary,
        base,
      ]) {
        expect(tester.getRect(content).left - sheet.left, AppSpacing.xl);
      }
      // Copy trails the LTR answers on the right.
      final copy = tester.getRect(
        find.byKey(const ValueKey('translation-primary-copy')),
      );
      expect(copy.left, greaterThan(tester.getRect(primary).right - 1));
    });

    testWidgets('a selected phrase is a label like a word; its short answer is '
        'the heading', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: const TextSelectionContext(
          selectedText: 'in want of',
          contextText: 'A single man must be in want of a wife.',
          markedContextText: 'A single man must be [[in want of]] a wife.',
          sourceId: 'source-1',
          sourceType: SourceType.book,
          sourceLanguageHint: 'en',
        ),
        service: WordTranslationService(
          const ContextualTranslationText(
            contextualTranslation: 'нуждается в',
            sentenceTranslation: 'Холостяк нуждается в жене.',
          ),
          analysis: const ContextualTranslationAnalysis(
            surfaceForm: 'in want of',
            expressionType: 'phrase',
          ),
        ),
      );
      expectSubject(tester);
      final theme = Theme.of(tester.element(primary));
      expect(
        tester.widget<SelectableText>(primary).style,
        theme.textTheme.headlineSmall!.copyWith(letterSpacing: 0),
      );
      expect(find.byType(AppLexicalMetadataRow), findsNothing);
    });

    testWidgets('words too wide at a large text size shrink instead of '
        'breaking', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Test glyphs are squares: at 2x neither word fits its line at its own
      // size, both fit at a smaller one.
      const word = 'fortunes';
      await pumpTranslateSheet(
        tester,
        selection: const TextSelectionContext(
          selectedText: word,
          sourceId: 'source-1',
          sourceType: SourceType.book,
        ),
        textScaler: const TextScaler.linear(2),
        service: WordTranslationService(
          const ContextualTranslationText(contextualTranslation: 'удачный'),
        ),
      );
      final theme = Theme.of(tester.element(selectedFragmentFinder));
      const scaled = TextScaler.linear(2);
      for (final (finder, role) in [
        (selectedFragmentFinder, theme.textTheme.titleMedium!),
        (primary, theme.textTheme.headlineSmall!),
      ]) {
        final style = tester.widget<SelectableText>(finder).style!;
        expect(style.fontSize, lessThan(role.fontSize!));
        expect(
          style.fontSize,
          greaterThanOrEqualTo(theme.textTheme.bodyMedium!.fontSize!),
        );
        // One line: the word was not broken.
        expect(
          tester.getSize(finder).height,
          closeTo(scaled.scale(style.fontSize!) * style.height!, 1),
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
