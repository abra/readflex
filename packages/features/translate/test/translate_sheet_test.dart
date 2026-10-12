import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import 'helpers/translate_sheet_harness.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'word and contextual meanings are visible with independent copy',
    (tester) async {
      final copied = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final service = WordTranslationService(
        const ContextualTranslationText(
          baseTranslation: 'сила',
          contextualTranslation: 'питание',
          sentenceTranslation:
              'Этот аккумулятор обеспечивает аварийное питание.',
        ),
      );
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: service,
      );
      final primary = find.byKey(const ValueKey('translation-primary-result'));
      final generalMeaning = find.byKey(
        const ValueKey('translation-base-result'),
      );
      expect(tester.widget<SelectableText>(primary).data, 'питание');
      expect(generalMeaning.hitTestable(), findsOneWidget);
      expect(find.text('In this context'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.tap(find.byKey(const ValueKey('translation-primary-copy')));
      await tester.pumpAndSettle();
      expect(tester.widget<SelectableText>(generalMeaning).data, 'сила');
      expect(
        tester.widget<SelectableText>(generalMeaning).style,
        Theme.of(
          tester.element(generalMeaning),
        ).textTheme.bodyLarge!.copyWith(letterSpacing: 0),
      );
      expect(
        tester.getTopLeft(generalMeaning).dy,
        greaterThan(tester.getTopLeft(primary).dy),
      );
      expect(find.text('Word meaning'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('translation-sentence-result')),
        findsOneWidget,
      );
      final copyGeneralMeaning = find.byKey(
        const ValueKey('translation-base-copy'),
      );
      await tester.ensureVisible(copyGeneralMeaning);
      await tester.tap(copyGeneralMeaning);
      await tester.pumpAndSettle();
      expect(copied, ['питание', 'сила']);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final example in [
    (
      word: 'rather',
      expression: 'rather than',
      base: 'скорее; довольно',
      translated: 'вместо того чтобы',
      sentence: 'She walked rather than waited for the bus.',
    ),
    (
      word: 'into',
      expression: 'falls into',
      base: 'в',
      translated: 'относится к',
      sentence: 'This service falls into the same category.',
    ),
    (
      word: 'shutting',
      expression: 'shutting the device off',
      base: 'закрывающий',
      translated: 'выключение устройства',
      sentence: 'Try shutting the device off.',
    ),
    (
      word: '気',
      expression: '気をつけて',
      base: 'дух',
      translated: 'будь осторожен',
      sentence: '気をつけて帰ってね。',
    ),
  ]) {
    testWidgets('shows the source scope of ${example.expression}', (
      tester,
    ) async {
      final service = WordTranslationService(
        ContextualTranslationText(
          baseTranslation: example.base,
          sentenceTranslation: 'A complete translated sentence.',
        ),
        expression: ContextualTranslationExpression(
          text: example.expression,
          translation: example.translated,
        ),
      );
      await pumpTranslateSheet(
        tester,
        service: service,
        selection: TextSelectionContext(
          selectedText: example.word,
          contextText: example.sentence,
          sourceId: 'source-1',
          sourceType: SourceType.book,
        ),
      );
      expect(find.text(example.word), findsOneWidget);
      expect(find.text('In this context'), findsOneWidget);
      final scope = find.byKey(
        const ValueKey('translation-contextual-expression'),
      );
      final primary = find.byKey(const ValueKey('translation-primary-result'));
      expect(tester.widget<SelectableText>(scope).data, example.expression);
      expect(tester.widget<SelectableText>(primary).data, example.translated);
      expect(
        tester.getTopLeft(scope).dy,
        lessThan(tester.getTopLeft(primary).dy),
      );
      final base = find.byKey(const ValueKey('translation-base-result'));
      expect(tester.widget<SelectableText>(base).data, example.base);
      expect(base.hitTestable(), findsOneWidget);
      expect(
        tester.getTopLeft(base).dy,
        greaterThan(tester.getTopLeft(primary).dy),
      );
      expect(
        find.byKey(const ValueKey('translation-sentence-result')),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rather without a larger expression keeps both word meanings', (
    tester,
  ) async {
    final service = WordTranslationService(
      const ContextualTranslationText(
        baseTranslation: 'скорее; довольно',
        contextualTranslation: 'довольно',
        sentenceTranslation: 'Здесь довольно тихо.',
      ),
    );
    await pumpTranslateSheet(
      tester,
      service: service,
      selection: const TextSelectionContext(
        selectedText: 'rather',
        contextText: 'It is rather quiet here.',
        markedContextText: 'It is [[rather]] quiet here.',
        sourceId: 'source-1',
        sourceType: SourceType.article,
      ),
    );
    expect(find.text('скорее; довольно').hitTestable(), findsOneWidget);
    expect(find.text('довольно').hitTestable(), findsOneWidget);
    expect(find.text('In this context'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('translation-contextual-expression')),
      findsNothing,
    );
    expect(find.byType(ExpansionTile), findsNothing);
    expect(service.calls, 1);
  });

  for (final example in [
    (
      name: 'equal translations still describe different source spans',
      translation: const ContextualTranslationText(baseTranslation: 'выключен'),
      wordAnswer: 'выключен',
    ),
    (
      name:
          'missing base does not relabel a contextual fallback as a word meaning',
      translation: const ContextualTranslationText(
        contextualTranslation: 'отключён',
      ),
      wordAnswer: null,
    ),
    (
      name: 'expression-only response does not invent a word translation',
      translation: const ContextualTranslationText(),
      wordAnswer: null,
    ),
  ]) {
    testWidgets(example.name, (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: const TextSelectionContext(
          selectedText: 'off',
          contextText: 'The device is switched off.',
          sourceId: 'source-1',
          sourceType: SourceType.book,
        ),
        service: WordTranslationService(
          example.translation,
          expression: const ContextualTranslationExpression(
            text: 'switched off',
            translation: 'выключен',
          ),
        ),
      );
      final word = find.byKey(const ValueKey('translation-base-result'));
      if (example.wordAnswer case final answer?) {
        expect(tester.widget<SelectableText>(word).data, answer);
      } else {
        expect(word, findsNothing);
      }
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('translation-primary-result')),
            )
            .data,
        'выключен',
      );
      expect(find.text('switched off'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
    });
  }

  for (final entry in <String, ContextualTranslationText>{
    'identical': const ContextualTranslationText(
      baseTranslation: 'сила',
      contextualTranslation: 'сила',
    ),
    'case and whitespace': const ContextualTranslationText(
      baseTranslation: '  Сила  ',
      contextualTranslation: 'сила',
    ),
    'context only': const ContextualTranslationText(
      contextualTranslation: 'сила',
    ),
    'base only': const ContextualTranslationText(baseTranslation: 'сила'),
    'blank base': const ContextualTranslationText(
      baseTranslation: '  ',
      contextualTranslation: 'сила',
    ),
    'offline fragment': const ContextualTranslationText(
      translatedFragment: 'сила',
    ),
  }.entries) {
    testWidgets('does not duplicate word answer: ${entry.key}', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: WordTranslationService(entry.value),
      );
      expect(
        find.byKey(const ValueKey('translation-primary-result')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('translation-base-result')),
        findsNothing,
      );
      expect(find.text('In this context'), findsNothing);
      expect(find.byTooltip('Copy'), findsOneWidget);
    });
  }

  for (final locale in ReadflexSupportedLocales.locales) {
    testWidgets(
      'both answers fit narrow large-text UI: ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpTranslateSheet(
          tester,
          selection: powerSelection,
          locale: locale,
          textScaler: const TextScaler.linear(2),
          service: WordTranslationService(
            const ContextualTranslationText(
              baseTranslation: 'ordinary meaning with several words',
              contextualTranslation: 'معنى الكلمة في سياق الجملة',
            ),
            analysis: const ContextualTranslationAnalysis(
              surfaceForm: 'power',
              pronunciation: '/ˈpaʊər/',
              partOfSpeech: 'noun',
              expressionType: 'word',
            ),
            expression: const ContextualTranslationExpression(
              text: 'supplies power',
              translation: 'معنى الكلمة في سياق الجملة',
            ),
          ),
        );
        final l10n = ReadflexLocalizations.of(
          tester.element(find.byType(TranslateSheet)),
        )!;
        expect(find.text(l10n.translationPosNoun), findsOneWidget);
        expect(find.text(l10n.translationInContext), findsOneWidget);
        expect(find.text('/ˈpaʊər/').hitTestable(), findsOneWidget);
        for (final id in ['primary', 'base']) {
          final result = find.byKey(ValueKey('translation-$id-result'));
          await tester.ensureVisible(result);
          expect(result.hitTestable(), findsOneWidget);
          final text = tester.widget<SelectableText>(result);
          expect(
            text.textDirection,
            id == 'primary' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            text.style,
            Theme.of(
              tester.element(result),
            ).textTheme.bodyLarge!.copyWith(letterSpacing: 0),
          );
          final copy = find.byKey(ValueKey('translation-$id-copy'));
          await tester.ensureVisible(copy);
          expect(copy.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final selection in [_phraseSelection, paragraphSelection]) {
    testWidgets(
      'base answer does not change multi-word selection: ${selection.selectedText}',
      (tester) async {
        await pumpTranslateSheet(
          tester,
          selection: selection,
          service: WordTranslationService(
            const ContextualTranslationText(
              baseTranslation: 'base',
              contextualTranslation: 'contextual answer',
            ),
            expression: const ContextualTranslationExpression(
              text: 'unwanted expansion',
              translation: 'wrong answer',
            ),
          ),
        );
        expect(find.text('base'), findsNothing);
        expect(find.text('contextual answer'), findsOneWidget);
        expect(find.text('General meaning'), findsNothing);
        expect(find.text('wrong answer'), findsNothing);
        expect(
          find.byKey(const ValueKey('translation-contextual-expression')),
          findsNothing,
        );
      },
    );
  }

  for (final expressionType in ['word', 'phrase', 'phrasal_verb', 'idiom']) {
    testWidgets(
      'word within $expressionType keeps pronunciation and base form',
      (tester) async {
        final service = WordTranslationService(
          const ContextualTranslationText(contextualTranslation: 'отключающий'),
          analysis: ContextualTranslationAnalysis(
            selectedTokenIds: const [3],
            expressionTokenIds: expressionType == 'word'
                ? const [3]
                : const [3, 4],
            surfaceForm: 'shutting',
            lemma: 'shut',
            pronunciation: '/ˈʃʌtɪŋ/',
            partOfSpeech: 'verb',
            expressionType: expressionType,
          ),
        );
        await pumpTranslateSheet(
          tester,
          service: service,
          selection: const TextSelectionContext(
            selectedText: 'shutting',
            contextText: 'The device is shutting off.',
            sourceId: 'source-1',
            sourceType: SourceType.book,
          ),
        );
        expect(find.text('shutting'), findsOneWidget);
        expect(find.text('/ˈʃʌtɪŋ/').hitTestable(), findsOneWidget);
        expect(find.text('Verb'), findsOneWidget);
        expect(find.text('Base form:'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('translation-lemma')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('shut'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(service.calls, 1);
      },
    );
  }

  for (final example in [
    (word: 'rather', locale: const Locale('ar'), direction: TextDirection.ltr),
    (word: 'قدرة', locale: const Locale('en'), direction: TextDirection.rtl),
  ]) {
    testWidgets(
      'word metadata row starts on the headword edge: ${example.word}',
      (tester) async {
        await pumpTranslateSheet(
          tester,
          locale: example.locale,
          selection: TextSelectionContext(
            selectedText: example.word,
            sourceId: 'source-1',
            sourceType: SourceType.book,
          ),
          service: WordTranslationService(
            const ContextualTranslationText(baseTranslation: 'word meaning'),
            analysis: ContextualTranslationAnalysis(
              surfaceForm: example.word,
              pronunciation: '/ipa/',
              partOfSpeech: 'noun',
            ),
          ),
        );
        final metadata = find.descendant(
          of: find.byType(AppLexicalMetadataRow),
          matching: find.byType(Wrap),
        );
        for (final row in metadata.evaluate()) {
          expect((row.widget as Wrap).textDirection, example.direction);
        }
        final word = tester.getRect(selectedFragmentFinder);
        final ipa = tester.getRect(find.text('/ipa/'));
        final l10n = ReadflexLocalizations.of(
          tester.element(find.byType(TranslateSheet)),
        )!;
        final noun = tester.getRect(find.text(l10n.translationPosNoun));
        // Pronunciation follows the word; grammar starts under it, on its
        // edge, in either UI.
        if (example.direction == TextDirection.ltr) {
          expect(ipa.left, greaterThan(word.right));
          expect(noun.left, word.left);
        } else {
          expect(ipa.right, lessThan(word.left));
          expect(noun.right, word.right);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final surface in <String?>[null, 'powered', 'power bank']) {
    testWidgets(
      'does not attribute pronunciation of $surface to selected word',
      (tester) async {
        await pumpTranslateSheet(
          tester,
          selection: powerSelection,
          service: WordTranslationService(
            const ContextualTranslationText(contextualTranslation: 'питание'),
            analysis: ContextualTranslationAnalysis(
              surfaceForm: surface,
              pronunciation: '/wrong/',
              reading: 'wrong reading',
              partOfSpeech: 'verb',
            ),
          ),
        );
        expect(find.text('/wrong/'), findsNothing);
        expect(find.text('wrong reading'), findsNothing);
        expect(find.byType(AppLexicalMetadataRow), findsNothing);
        expect(find.text('Verb'), findsNothing);
        expect(find.text('питание'), findsOneWidget);
      },
    );
  }

  testWidgets('blank metadata and unknown grammar add no empty controls', (
    tester,
  ) async {
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: WordTranslationService(
        const ContextualTranslationText(contextualTranslation: 'питание'),
        analysis: const ContextualTranslationAnalysis(
          surfaceForm: ' power ',
          lemma: ' POWER ',
          pronunciation: ' ',
          reading: '\n',
          partOfSpeech: 'unrecognized_tag',
        ),
      ),
    );
    expect(find.byType(AppLexicalMetadataRow), findsNothing);
    expect(find.byKey(const ValueKey('translation-lemma')), findsNothing);
    expect(find.text('unrecognized_tag'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  for (final entry in {'銀行': 'ぎんこう', '银行': 'yín háng'}.entries) {
    testWidgets(
      'reading for ${entry.key} is visible without duplicate pronunciation',
      (tester) async {
        await pumpTranslateSheet(
          tester,
          selection: TextSelectionContext(
            selectedText: entry.key,
            sourceId: 'source-1',
            sourceType: SourceType.book,
          ),
          service: WordTranslationService(
            const ContextualTranslationText(contextualTranslation: 'банк'),
            analysis: ContextualTranslationAnalysis(
              surfaceForm: entry.key,
              reading: entry.value,
              pronunciation: entry.value,
              expressionType: 'word',
            ),
          ),
        );
        expect(find.text(entry.value).hitTestable(), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(entry.value)).style!.fontFamily,
          isNot(AppTypography.fontFamilyPhonetic),
        );
        expect(find.byType(ExpansionTile), findsNothing);
      },
    );
  }

  for (final selectedTokenIds in <List<int>>[
    [],
    [1, 2, 3],
    [9],
  ]) {
    testWidgets(
      'a non-spaced phrase stays a phrase: tokens $selectedTokenIds',
      (tester) async {
        await pumpTranslateSheet(
          tester,
          selection: const TextSelectionContext(
            selectedText: '銀行に行く',
            sourceId: 'source-1',
            sourceType: SourceType.book,
          ),
          service: WordTranslationService(
            const ContextualTranslationText(
              baseTranslation: 'банк',
              contextualTranslation: 'идти в банк',
            ),
            analysis: ContextualTranslationAnalysis(
              selectedTokenIds: selectedTokenIds,
              expressionTokenIds: const [1, 2, 3],
              surfaceForm: '銀行に行く',
              reading: 'ぎんこうにいく',
              expressionType: 'phrase',
            ),
          ),
        );
        expect(find.text('идти в банк'), findsOneWidget);
        expect(find.text('банк'), findsNothing);
        expect(find.text('ぎんこうにいく'), findsNothing);
        expectSubject(tester);
      },
    );
  }

  testWidgets(
    'copy writes the result, not the selection, without translating again',
    (tester) async {
      final service = _RecordingTranslationService();
      final copied = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpTranslateSheet(
        tester,
        selection: paragraphSelection,
        service: service,
      );
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(copied, ['Запуски в наши дни в основном произвольны.']);
      expect(service.calls, 1);
      expect(find.byTooltip('Copied'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('translation-primary-result')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('large text on a narrow sheet keeps language selection usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: _SourceRequiredService(),
      textScaler: const TextScaler.linear(2),
    );
    final source = find.byKey(const ValueKey('translation-source-language'));
    final target = find.byKey(const ValueKey('translation-target-language'));
    expect(tester.getTopLeft(source).dx, tester.getTopLeft(target).dx);
    expect(
      tester.getBottomLeft(source).dy,
      lessThan(tester.getTopLeft(target).dy),
    );
    final action = find.widgetWithText(FilledButton, 'Select language');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').hitTestable().last);
    await tester.pumpAndSettle();
    expect(find.text('сила'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing source opens language picker without retrying', (
    tester,
  ) async {
    final service = _SourceRequiredService();
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: service,
    );
    expect(service.sources, ['auto']);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Select language'));
    await tester.pumpAndSettle();
    expect(service.sources, ['auto']);
    await tester.tap(find.text('English').hitTestable().last);
    await tester.pumpAndSettle();
    expect(service.sources, ['auto', 'en']);
    expect(find.text('сила'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders contextual source preview and compact language selectors',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTranslateSheet(tester, selection: powerSelection);

      expect(find.text('From'), findsNothing);
      expect(find.text('To'), findsNothing);
      expect(find.bySemanticsLabel('From'), findsOneWidget);
      expect(find.bySemanticsLabel('To'), findsOneWidget);

      final selectors = find.byWidgetPredicate(
        (widget) =>
            widget.key == const ValueKey('translation-source-language') ||
            widget.key == const ValueKey('translation-target-language'),
      );
      expect(selectors, findsNWidgets(2));
      for (final selector in selectors.evaluate()) {
        expect(
          tester.getSize(find.byWidget(selector.widget)).height,
          AppSizes.buttonHeight,
        );
      }
      expect(find.text('English'), findsOneWidget);
      expect(find.text('English -> Русский'), findsNothing);
      expect(tester.getSize(selectors.last).width, lessThan(160));
      final preview = _previewText(tester);
      expect(
        preview.textSpan?.toPlainText(),
        'This power bank provides emergency power.',
      );
      final selectedSpan = _previewSpans(
        tester,
      ).singleWhere((span) => span.text == 'power');
      final colors = Theme.of(tester.element(previewFinder)).colorScheme;
      expect(selectedSpan.style?.fontWeight, FontWeight.w600);
      expect(preview.textSpan?.style?.color, colors.onSurfaceVariant);
      expect(selectedSpan.style?.color, colors.onSurface);
      expect(selectedSpan.style?.backgroundColor, isNull);

      final translation = find.byKey(
        const ValueKey('translation-primary-result'),
      );
      final translationWidget = tester.widget<SelectableText>(translation);
      expect(translationWidget.data, 'сила');
      expect(
        translationWidget.style,
        Theme.of(
          tester.element(translation),
        ).textTheme.headlineSmall!.copyWith(letterSpacing: 0),
      );
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('the source sentence is muted, the selection in body color: '
        '$brightness', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        brightness: brightness,
      );
      final baseStyle = _previewText(tester).textSpan!.style!;
      final theme = Theme.of(tester.element(previewFinder));
      expect(baseStyle.color, theme.colorScheme.onSurfaceVariant);
      expect(
        tester.widget<SelectableText>(selectedFragmentFinder).style!.color,
        theme.colorScheme.onSurface,
      );
      final background =
          theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface;
      double contrast(Color a, Color b) {
        final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
        return (luminances.last + 0.05) / (luminances.first + 0.05);
      }

      expect(contrast(baseStyle.color!, background), greaterThanOrEqualTo(4.5));
      final selectedStyle = _previewSpans(
        tester,
      ).singleWhere((span) => span.text == 'power').style!;
      expect(selectedStyle.backgroundColor, isNull);
      expect(selectedStyle.background, isNull);
      expect(
        selectedStyle,
        baseStyle.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      );
      expect(
        contrast(selectedStyle.color!, background),
        greaterThanOrEqualTo(7),
      );
    });
  }

  testWidgets('the word is a label; no result text is quoted', (tester) async {
    await pumpTranslateSheet(tester, selection: powerSelection);
    expectSubject(tester);
    _expectMutedSource(tester, previewFinder);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('translation-primary-result')),
        matching: quoteSurfaceFinder,
      ),
      findsNothing,
    );
    expect(find.byType(AppSourceQuote), findsNothing);
    // Space separates the sections; only the details tile keeps its border.
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets(
    'lexical lookup keeps the sentence visible and details collapsed',
    (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: const FakeTranslationService(includeLexicalDetails: true),
      );

      expect(find.text('питание'), findsOneWidget);
      expect(find.text('Sentence'), findsOneWidget);
      expect(
        find.text('Этот аккумулятор обеспечивает аварийное питание.'),
        findsOneWidget,
      );
      expect(find.text('power'), findsOneWidget);
      expect(find.text('Lexical explanation'), findsNothing);
      expect(find.text('релизы'), findsNothing);
      expect(find.text('Meaning & alternatives'), findsOneWidget);

      final primary = find.byKey(const ValueKey('translation-primary-result'));
      final sentence = find.byKey(
        const ValueKey('translation-sentence-result'),
      );
      expect(
        tester.getTopLeft(primary).dy,
        lessThan(tester.getTopLeft(previewFinder).dy),
      );
      expect(
        tester.getTopLeft(previewFinder).dy,
        lessThan(tester.getTopLeft(sentence).dy),
      );
      expect(
        tester.getTopLeft(sentence).dy,
        lessThan(tester.getTopLeft(find.text('Meaning & alternatives')).dy),
      );
      await tester.tap(find.text('Meaning & alternatives'));
      await tester.pumpAndSettle();
      expect(find.text('power'), findsOneWidget);
      expect(find.text('Lexical explanation'), findsOneWidget);
      expect(find.text('релизы'), findsOneWidget);
    },
  );

  testWidgets('text translation uses exact source and hides lexical fields', (
    tester,
  ) async {
    await pumpTranslateSheet(
      tester,
      selection: paragraphSelection,
      service: const FakeTranslationService(includeLexicalDetails: true),
    );

    expect(
      _previewText(tester).textSpan?.toPlainText(),
      paragraphSelection.selectedText,
    );
    _expectMutedSource(tester, previewFinder);
    expect(find.text('Запуски в наши дни в основном произвольны.'), findsOne);
    expect(find.text('power'), findsNothing);
    expect(find.text('Sentence'), findsNothing);
    expect(find.text('Lexical explanation'), findsNothing);
    expect(find.text('релизы'), findsNothing);

    final translation = find.byKey(
      const ValueKey('translation-primary-result'),
    );
    final translationWidget = tester.widget<SelectableText>(translation);
    expect(find.text('Original'), findsOneWidget);
    expect(
      tester.getTopLeft(translation).dy,
      lessThan(tester.getTopLeft(previewFinder).dy),
    );
    expect(
      translationWidget.style,
      Theme.of(
        tester.element(translation),
      ).textTheme.bodyLarge!.copyWith(letterSpacing: 0),
    );
  });

  testWidgets('short multi-word translation uses readable body typography', (
    tester,
  ) async {
    await pumpTranslateSheet(tester, selection: _phraseSelection);

    final translation = find.byKey(
      const ValueKey('translation-primary-result'),
    );
    final translationWidget = tester.widget<SelectableText>(translation);
    expect(
      translationWidget.style,
      Theme.of(
        tester.element(translation),
      ).textTheme.bodyLarge!.copyWith(letterSpacing: 0),
    );
  });

  testWidgets('a long answer to one word still uses body typography', (
    tester,
  ) async {
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: const FakeTranslationService(
        primary: 'A longer explanation of the selected word in this context.',
      ),
    );
    final result = find.byKey(const ValueKey('translation-primary-result'));
    expect(
      tester.widget<SelectableText>(result).style,
      Theme.of(
        tester.element(result),
      ).textTheme.bodyLarge!.copyWith(letterSpacing: 0),
    );
  });

  testWidgets('long context cannot push the primary answer below the fold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final contextText =
        'Before. ${List.filled(100, 'More context.').join(' ')} '
        'The power bank is compact.';
    final service = _RecordingTranslationService();
    await pumpTranslateSheet(
      tester,
      selection: TextSelectionContext(
        selectedText: 'power',
        contextText: contextText,
        markedContextText: contextText.replaceFirst('power', '[[power]]'),
        sourceId: 'source-1',
        sourceType: SourceType.book,
      ),
      service: service,
    );
    expect(
      find.byKey(const ValueKey('translation-primary-result')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byTooltip('Copy').hitTestable(), findsOneWidget);
    expect(_previewText(tester).textSpan!.toPlainText(), contextText);
    _expectMutedSource(tester, previewFinder);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed marked context falls back to clean context text', (
    tester,
  ) async {
    await pumpTranslateSheet(tester, selection: _malformedMarkedSelection);

    final preview = _previewText(tester);
    expect(
      preview.textSpan?.toPlainText(),
      'A portable battery stores power safely.',
    );
    expect(preview.textSpan?.toPlainText(), isNot(contains('[[')));
    expect(
      _previewSpans(tester).singleWhere((span) => span.text == 'power'),
      isNotNull,
    );
  });

  testWidgets('stale marked context is rejected for the current selection', (
    tester,
  ) async {
    await pumpTranslateSheet(tester, selection: _staleMarkedSelection);

    expect(
      _previewText(tester).textSpan?.toPlainText(),
      'This power bank is compact.',
    );
    expect(
      _previewSpans(tester).singleWhere((span) => span.text == 'power bank'),
      isNotNull,
    );
  });

  for (final profile in [
    (
      name: 'phone',
      size: const Size(390, 600),
      scale: 1.0,
      locale: const Locale('en'),
    ),
    (
      name: 'large text',
      size: const Size(320, 568),
      scale: 2.0,
      locale: const Locale('ru'),
    ),
    (
      name: 'RTL',
      size: const Size(390, 844),
      scale: 1.0,
      locale: const Locale('ar'),
    ),
  ]) {
    testWidgets(
      'language direction remains fixed while scrolling: ${profile.name}',
      (tester) async {
        tester.view.physicalSize = profile.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _RecordingTranslationService(
          includeLexicalDetails: true,
          alternativeCount: 20,
        );
        await pumpTranslateSheet(
          tester,
          selection: powerSelection,
          service: service,
          locale: profile.locale,
          textScaler: TextScaler.linear(profile.scale),
        );
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        final scrollView = find.byType(SingleChildScrollView);
        final scroll = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scrollView, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final source = find.byKey(
          const ValueKey('translation-source-language'),
        );
        final target = find.byKey(
          const ValueKey('translation-target-language'),
        );
        final l10n = ReadflexLocalizations.of(tester.element(source))!;
        final title = find.text(l10n.translationTitle);
        final titleRect = tester.getRect(title);
        final sourceRect = tester.getRect(source);
        final targetRect = tester.getRect(target);
        final primary = find.byKey(
          const ValueKey('translation-primary-result'),
        );
        final answerTop = tester.getTopLeft(primary).dy;
        expect(scroll.maxScrollExtent, greaterThan(0));
        scroll.jumpTo(scroll.maxScrollExtent);
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(primary).dy, lessThan(answerTop));
        expect(tester.getRect(title), titleRect);
        expect(tester.getRect(source), sourceRect);
        expect(tester.getRect(target), targetRect);
        expect(sourceRect.top, greaterThanOrEqualTo(titleRect.bottom));
        expect(
          targetRect.bottom,
          lessThanOrEqualTo(tester.getRect(scrollView).top),
        );
        expect(source.hitTestable(), findsOneWidget);
        expect(target.hitTestable(), findsOneWidget);
        expect(service.calls, 1);

        // No ensureVisible: changing direction must work from the scrolled body.
        await tester.tap(target);
        await tester.pumpAndSettle();
        // Large text uses a bounded, scrollable single-column menu.
        await tester.ensureVisible(
          find.widgetWithText(MenuItemButton, 'Deutsch'),
        );
        await tester.tap(find.text('Deutsch').hitTestable().last);
        await tester.pumpAndSettle();
        expect(service.calls, 2);
        expect(service.requests.last.targetLanguage, 'de');
        expect(
          service.requests.last.selection.text,
          powerSelection.selectedText,
        );
        expect(find.text('Lexical explanation'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('edge shadows follow expanded details scroll: $brightness', (
      tester,
    ) async {
      final service = _RecordingTranslationService(
        includeLexicalDetails: true,
        alternativeCount: 20,
      );
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: service,
        brightness: brightness,
      );
      final topFade = find.byWidgetPredicate(
        (widget) =>
            widget is ScrollEdgeFade && widget.edge == ScrollFadeEdge.top,
      );
      final bottomFade = find.byWidgetPredicate(
        (widget) =>
            widget is ScrollEdgeFade && widget.edge == ScrollFadeEdge.bottom,
      );
      expect(topFade, findsOneWidget);
      expect(bottomFade, findsOneWidget);
      expect(tester.widget<ScrollEdgeFade>(topFade).visible, isFalse);
      expect(tester.widget<ScrollEdgeFade>(bottomFade).visible, isFalse);
      final details = find.byType(ExpansionTile);
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      expect(tester.widget<ScrollEdgeFade>(bottomFade).visible, isTrue);
      final headerTop = tester.getTopLeft(find.text('Translation'));
      expect(
        tester.getTopLeft(topFade).dy,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('translation-target-language')),
              )
              .dy,
        ),
      );
      scroll.jumpTo(scroll.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      expect(tester.widget<ScrollEdgeFade>(topFade).visible, isTrue);
      expect(tester.widget<ScrollEdgeFade>(bottomFade).visible, isTrue);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.widget<ScrollEdgeFade>(topFade).visible, isTrue);
      expect(tester.widget<ScrollEdgeFade>(bottomFade).visible, isFalse);
      expect(tester.getTopLeft(find.text('Translation')), headerTop);
      expect(
        tester.getSize(topFade).width,
        tester.getSize(find.byType(TranslateSheet)).width,
      );
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<ScrollEdgeFade>(topFade).visible, isFalse);
      expect(tester.widget<ScrollEdgeFade>(bottomFade).visible, isTrue);
      final detailsTitle = find.text('Meaning & alternatives');
      await tester.ensureVisible(detailsTitle);
      await tester.tap(detailsTitle);
      await tester.pumpAndSettle();
      expect(scroll.maxScrollExtent, 0);
      expect(tester.widget<ScrollEdgeFade>(topFade).visible, isFalse);
      expect(tester.widget<ScrollEdgeFade>(bottomFade).visible, isFalse);
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long lexical result is constrained and scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: const FakeTranslationService(
        includeLexicalDetails: true,
        alternativeCount: 16,
      ),
    );

    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    await tester.ensureVisible(find.text('Meaning & alternatives'));
    await tester.tap(find.text('Meaning & alternatives'));
    await tester.pumpAndSettle();
    expect(tester.getSize(scrollView).height, lessThanOrEqualTo(600 * 0.68));
    expect(find.text('вариант 16'), findsOneWidget);
    await tester.ensureVisible(find.text('вариант 16'));
    expect(find.text('вариант 16').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanding details does not request another translation', (
    tester,
  ) async {
    final service = _RecordingTranslationService(includeLexicalDetails: true);
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: service,
    );
    final toggle = find.text('Meaning & alternatives');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Lexical explanation'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Lexical explanation'), findsNothing);
    expect(service.calls, 1);
    expect(
      _previewText(tester).textSpan!.toPlainText(),
      powerSelection.contextText,
    );
  });

  testWidgets('changing target requests once and collapses previous details', (
    tester,
  ) async {
    final service = _RecordingTranslationService(includeLexicalDetails: true);
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: service,
    );
    await tester.tap(find.text('Meaning & alternatives'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('translation-target-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').hitTestable().last);
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(service.requests.last.targetLanguage, 'de');
    expect(service.requests.last.sourceLanguage, 'auto');
    expect(service.requests.last.selection.text, powerSelection.selectedText);
    expect(find.text('Lexical explanation'), findsNothing);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('no empty details control is shown', (tester) async {
    await pumpTranslateSheet(tester, selection: powerSelection);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  for (final locale in ReadflexSupportedLocales.locales) {
    testWidgets('translation surface and action are localized: $locale', (
      tester,
    ) async {
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: const FakeTranslationService(includeLexicalDetails: true),
        locale: locale,
      );
      final context = tester.element(find.byType(TranslateSheet));
      final l10n = context.l10n;
      expect(l10n.localeName, locale.toString());
      expect(find.text(l10n.translationTitle), findsOneWidget);
      expect(find.text(l10n.translationDetails), findsOneWidget);
      expect(find.text('English'), findsOne);
      final sheet = tester.widget<TranslateSheet>(find.byType(TranslateSheet));
      final action = TranslateAction(
        translationService: sheet.translationService,
        preferencesService: sheet.preferencesService,
      );
      expect(action.labelFor(context), l10n.translationAction);
      expect(action.icon, AppIcons.translate);
      expect(action.icon, isNot(AppIcons.language));
      await tester.tap(find.text(l10n.translationDetails));
      await tester.pumpAndSettle();
      expect(find.text(l10n.translationAlternatives), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selecting the current target does not translate again', (
    tester,
  ) async {
    final service = _RecordingTranslationService();
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: service,
    );
    await tester.tap(find.byKey(const ValueKey('translation-target-language')));
    await tester.pumpAndSettle();
    final option = find.widgetWithText(MenuItemButton, 'Русский');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
  });

  testWidgets('LTR source and result keep their direction in an Arabic UI', (
    tester,
  ) async {
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      locale: const Locale('ar'),
      service: const FakeTranslationService(includeLexicalDetails: true),
    );
    expect(_previewText(tester).textDirection, TextDirection.ltr);
    expect(
      tester.widget<SelectableText>(selectedFragmentFinder).textDirection,
      TextDirection.ltr,
    );
    _expectMutedSource(tester, previewFinder, uiDirection: TextDirection.rtl);
    for (final key in [
      'translation-primary-result',
      'translation-sentence-result',
    ]) {
      expect(
        tester.widget<SelectableText>(find.byKey(ValueKey(key))).textDirection,
        TextDirection.ltr,
      );
    }
  });

  testWidgets('Arabic source keeps its direction in an English UI', (
    tester,
  ) async {
    await pumpTranslateSheet(
      tester,
      selection: const TextSelectionContext(
        selectedText: 'الطاقة',
        contextText: 'توفر هذه البطارية الطاقة للأجهزة.',
        markedContextText: 'توفر هذه البطارية [[الطاقة]] للأجهزة.',
        sourceId: 'source-1',
        sourceType: SourceType.article,
        sourceLanguageHint: 'ar',
      ),
    );
    expect(_previewText(tester).textDirection, TextDirection.rtl);
    expect(
      tester.widget<SelectableText>(selectedFragmentFinder).textDirection,
      TextDirection.rtl,
    );
    _expectMutedSource(tester, previewFinder, direction: TextDirection.rtl);
    expect(
      _previewText(tester).textSpan!.toPlainText(),
      'توفر هذه البطارية الطاقة للأجهزة.',
    );
  });

  testWidgets('does not render raw service failure details', (tester) async {
    await pumpTranslateSheet(
      tester,
      selection: powerSelection,
      service: const _FailingTranslationService(),
    );

    expect(find.text('Translation failed'), findsOneWidget);
    expect(
      find.text('Check the network connection or try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('credential leaked'), findsNothing);
    _expectSourceQuote(tester, previewFinder);
  });
}

void _expectSourceQuote(
  WidgetTester tester,
  Finder text, {
  TextDirection direction = TextDirection.ltr,
}) {
  final surface = find.ancestor(of: text, matching: quoteSurfaceFinder);
  expect(surface, findsOneWidget);
  final container = tester.widget<Container>(surface);
  final decoration = container.decoration! as BoxDecoration;
  final border = decoration.border! as BorderDirectional;
  final actualDirection = Directionality.of(tester.element(surface));
  expect(actualDirection, direction);
  final insets = border.dimensions.resolve(actualDirection);
  final isRtl = direction == TextDirection.rtl;
  expect(decoration.color, isNull);
  expect((isRtl ? insets.right : insets.left), 2);
  expect((isRtl ? insets.left : insets.right), 0);
  expect(border.end.style, BorderStyle.none);
  expect(border.top.style, BorderStyle.none);
  expect(border.bottom.style, BorderStyle.none);

  final textRect = tester.getRect(text);
  final quoteRect = tester.getRect(surface);
  final inset = isRtl
      ? quoteRect.right - textRect.right
      : textRect.left - quoteRect.left;
  expect(inset, closeTo(AppSpacing.md + 2, 0.01));
  expect(quoteRect.height, closeTo(textRect.height + 2 * AppSpacing.xs, 0.01));
}

/// A source line in a successful result: muted, unquoted, on the gutter of
/// its own writing direction.
void _expectMutedSource(
  WidgetTester tester,
  Finder text, {
  TextDirection direction = TextDirection.ltr,
  TextDirection uiDirection = TextDirection.ltr,
}) {
  expect(find.ancestor(of: text, matching: quoteSurfaceFinder), findsNothing);
  final widget = tester.widget<Text>(text);
  expect(widget.textDirection, direction);
  expect(
    widget.textSpan!.style!.color,
    Theme.of(tester.element(text)).colorScheme.onSurfaceVariant,
  );
  final rect = tester.getRect(text);
  final sheet = tester.getRect(find.byType(TranslateSheet));
  // The box spans both gutters; the text starts on its own start edge.
  expect(rect.left - sheet.left, AppSpacing.xl);
  expect(sheet.right - rect.right, AppSpacing.xl);
  expect(Directionality.of(tester.element(text)), uiDirection);
}

Text _previewText(WidgetTester tester) => tester.widget<Text>(previewFinder);

List<TextSpan> _previewSpans(WidgetTester tester) {
  final root = _previewText(tester).textSpan! as TextSpan;
  return root.children!.whereType<TextSpan>().toList(growable: false);
}

const _phraseSelection = TextSelectionContext(
  selectedText: 'power bank',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _malformedMarkedSelection = TextSelectionContext(
  selectedText: 'power',
  contextText: 'A portable battery stores power safely.',
  markedContextText: 'A portable battery stores [[power safely.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _staleMarkedSelection = TextSelectionContext(
  selectedText: 'power bank',
  contextText: 'This power bank is compact.',
  markedContextText: 'This [[power]] bank is compact.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class _FailingTranslationService implements ContextualTranslationService {
  const _FailingTranslationService();

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) {
    throw const ContextualTranslationException(
      ContextualTranslationFailureReason.http,
      'internal provider credential leaked',
      statusCode: 500,
    );
  }

  @override
  void dispose() {}
}

class _RecordingTranslationService extends FakeTranslationService {
  _RecordingTranslationService({
    super.includeLexicalDetails,
    super.alternativeCount,
  });

  var calls = 0;
  final requests = <ContextualTranslationRequest>[];

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) {
    calls++;
    requests.add(request);
    return super.translate(
      request,
      allowOfflineModelDownload: allowOfflineModelDownload,
    );
  }
}

class _SourceRequiredService implements ContextualTranslationService {
  final sources = <String>[];

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    sources.add(request.sourceLanguage);
    if (request.sourceLanguage == 'auto') {
      throw const ContextualTranslationException(
        ContextualTranslationFailureReason.sourceLanguageRequired,
        'Source required',
      );
    }
    return const FakeTranslationService().translate(request);
  }

  @override
  void dispose() {}
}
