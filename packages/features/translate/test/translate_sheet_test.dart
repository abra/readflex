import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('word shows base and contextual answers with independent copy', (
    tester,
  ) async {
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
    final service = _WordTranslationService(
      const ContextualTranslationText(
        baseTranslation: 'сила',
        contextualTranslation: 'питание',
        sentenceTranslation: 'Этот аккумулятор обеспечивает аварийное питание.',
      ),
    );
    await _pumpTranslateSheet(tester, selection: _selection, service: service);
    expect(find.text('Word translation'), findsOneWidget);
    expect(find.text('In this context'), findsOneWidget);
    final primary = find.byKey(const ValueKey('translation-primary-result'));
    final contextual = find.byKey(
      const ValueKey('translation-contextual-result'),
    );
    expect(tester.widget<SelectableText>(primary).data, 'сила');
    expect(tester.widget<SelectableText>(contextual).data, 'питание');
    expect(
      tester.getTopLeft(primary).dy,
      lessThan(tester.getTopLeft(contextual).dy),
    );
    expect(
      find.byKey(const ValueKey('translation-sentence-result')),
      findsOneWidget,
    );
    for (final key in [
      'translation-primary-copy',
      'translation-contextual-copy',
    ]) {
      final button = find.byKey(ValueKey(key));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(copied, ['сила', 'питание']);
    expect(service.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
      await _pumpTranslateSheet(
        tester,
        selection: _selection,
        service: _WordTranslationService(entry.value),
      );
      expect(
        find.byKey(const ValueKey('translation-primary-result')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('translation-contextual-result')),
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
        await _pumpTranslateSheet(
          tester,
          selection: _selection,
          locale: locale,
          textScaler: const TextScaler.linear(2),
          service: _WordTranslationService(
            const ContextualTranslationText(
              baseTranslation: 'ordinary meaning with several words',
              contextualTranslation: 'معنى الكلمة في سياق الجملة',
            ),
          ),
        );
        final l10n = ReadflexLocalizations.of(
          tester.element(find.byType(TranslateSheet)),
        )!;
        expect(find.text(l10n.translationWord), findsOneWidget);
        expect(find.text(l10n.translationInContext), findsOneWidget);
        for (final id in ['primary', 'contextual']) {
          final result = find.byKey(ValueKey('translation-$id-result'));
          await tester.ensureVisible(result);
          expect(result.hitTestable(), findsOneWidget);
          final text = tester.widget<SelectableText>(result);
          expect(
            text.textDirection,
            id == 'primary' ? TextDirection.ltr : TextDirection.rtl,
          );
          expect(
            text.style,
            Theme.of(tester.element(result)).textTheme.bodyLarge,
          );
          final copy = find.byKey(ValueKey('translation-$id-copy'));
          await tester.ensureVisible(copy);
          expect(copy.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final selection in [_phraseSelection, _paragraphSelection]) {
    testWidgets(
      'base answer does not change multi-word selection: ${selection.selectedText}',
      (tester) async {
        await _pumpTranslateSheet(
          tester,
          selection: selection,
          service: _WordTranslationService(
            const ContextualTranslationText(
              baseTranslation: 'base',
              contextualTranslation: 'contextual answer',
            ),
          ),
        );
        expect(find.text('base'), findsNothing);
        expect(find.text('contextual answer'), findsOneWidget);
        expect(find.text('Word translation'), findsNothing);
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
      await _pumpTranslateSheet(
        tester,
        selection: _paragraphSelection,
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
    await _pumpTranslateSheet(
      tester,
      selection: _selection,
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
    await _pumpTranslateSheet(tester, selection: _selection, service: service);
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
      await _pumpTranslateSheet(tester, selection: _selection);

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
      expect(find.text('Auto: English'), findsOneWidget);
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
      expect(selectedSpan.style?.fontWeight, FontWeight.w600);
      expect(selectedSpan.style?.color, preview.textSpan?.style?.color);
      expect(selectedSpan.style?.backgroundColor, isNull);

      final translation = find.byKey(
        const ValueKey('translation-primary-result'),
      );
      final translationWidget = tester.widget<SelectableText>(translation);
      expect(translationWidget.data, 'сила');
      expect(
        translationWidget.style,
        Theme.of(tester.element(translation)).textTheme.titleLarge,
      );
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('context emphasis uses only font weight: $brightness', (
      tester,
    ) async {
      await _pumpTranslateSheet(
        tester,
        selection: _selection,
        brightness: brightness,
      );
      final baseStyle = _previewText(tester).textSpan!.style!;
      final theme = Theme.of(tester.element(_previewFinder));
      expect(baseStyle.color, theme.colorScheme.onSurface);
      expect(
        tester.widget<Text>(_selectedFragmentFinder).style!.color,
        theme.colorScheme.onSurface,
      );
      final background =
          theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface;
      final luminances = [
        baseStyle.color!.computeLuminance(),
        background.computeLuminance(),
      ]..sort();
      expect(
        (luminances.last + 0.05) / (luminances.first + 0.05),
        greaterThanOrEqualTo(7),
      );
      final selectedStyle = _previewSpans(
        tester,
      ).singleWhere((span) => span.text == 'power').style!;
      expect(selectedStyle.backgroundColor, isNull);
      expect(selectedStyle.background, isNull);
      expect(selectedStyle, baseStyle.copyWith(fontWeight: FontWeight.w600));
    });
  }

  testWidgets('only source fragments and context have a quotation rule', (
    tester,
  ) async {
    await _pumpTranslateSheet(tester, selection: _selection);
    _expectSourceQuote(tester, _selectedFragmentFinder);
    _expectSourceQuote(tester, _previewFinder);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('translation-primary-result')),
        matching: _quoteSurfaceFinder,
      ),
      findsNothing,
    );
  });

  testWidgets(
    'lexical lookup keeps the sentence visible and details collapsed',
    (tester) async {
      await _pumpTranslateSheet(
        tester,
        selection: _selection,
        service: const _FakeTranslationService(includeLexicalDetails: true),
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
        lessThan(tester.getTopLeft(_previewFinder).dy),
      );
      expect(
        tester.getTopLeft(_previewFinder).dy,
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
    await _pumpTranslateSheet(
      tester,
      selection: _paragraphSelection,
      service: const _FakeTranslationService(includeLexicalDetails: true),
    );

    expect(
      _previewText(tester).textSpan?.toPlainText(),
      _paragraphSelection.selectedText,
    );
    _expectSourceQuote(tester, _previewFinder);
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
      lessThan(tester.getTopLeft(_previewFinder).dy),
    );
    expect(
      translationWidget.style,
      Theme.of(tester.element(translation)).textTheme.bodyLarge,
    );
  });

  testWidgets('short multi-word translation uses readable body typography', (
    tester,
  ) async {
    await _pumpTranslateSheet(tester, selection: _phraseSelection);

    final translation = find.byKey(
      const ValueKey('translation-primary-result'),
    );
    final translationWidget = tester.widget<SelectableText>(translation);
    expect(
      translationWidget.style,
      Theme.of(tester.element(translation)).textTheme.bodyLarge,
    );
  });

  testWidgets('a long answer to one word still uses body typography', (
    tester,
  ) async {
    await _pumpTranslateSheet(
      tester,
      selection: _selection,
      service: const _FakeTranslationService(
        primary: 'A longer explanation of the selected word in this context.',
      ),
    );
    final result = find.byKey(const ValueKey('translation-primary-result'));
    expect(
      tester.widget<SelectableText>(result).style,
      Theme.of(tester.element(result)).textTheme.bodyLarge,
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
    await _pumpTranslateSheet(
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
    _expectSourceQuote(tester, _previewFinder);
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
    await _pumpTranslateSheet(tester, selection: _malformedMarkedSelection);

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
    await _pumpTranslateSheet(tester, selection: _staleMarkedSelection);

    expect(
      _previewText(tester).textSpan?.toPlainText(),
      'This power bank is compact.',
    );
    expect(
      _previewSpans(tester).singleWhere((span) => span.text == 'power bank'),
      isNotNull,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('edge shadows follow expanded details scroll: $brightness', (
      tester,
    ) async {
      final service = _RecordingTranslationService(
        includeLexicalDetails: true,
        alternativeCount: 20,
      );
      await _pumpTranslateSheet(
        tester,
        selection: _selection,
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

    await _pumpTranslateSheet(
      tester,
      selection: _selection,
      service: const _FakeTranslationService(
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
    await _pumpTranslateSheet(tester, selection: _selection, service: service);
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
      _selection.contextText,
    );
  });

  testWidgets('changing target requests once and collapses previous details', (
    tester,
  ) async {
    final service = _RecordingTranslationService(includeLexicalDetails: true);
    await _pumpTranslateSheet(tester, selection: _selection, service: service);
    await tester.tap(find.text('Meaning & alternatives'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('translation-target-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').hitTestable().last);
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(service.requests.last.targetLanguage, 'de');
    expect(service.requests.last.sourceLanguage, 'auto');
    expect(service.requests.last.selection.text, _selection.selectedText);
    expect(find.text('Lexical explanation'), findsNothing);
    expect(find.text('Auto: English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('no empty details control is shown', (tester) async {
    await _pumpTranslateSheet(tester, selection: _selection);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  for (final locale in ReadflexSupportedLocales.locales) {
    testWidgets('translation surface and action are localized: $locale', (
      tester,
    ) async {
      await _pumpTranslateSheet(
        tester,
        selection: _selection,
        service: const _FakeTranslationService(includeLexicalDetails: true),
        locale: locale,
      );
      final context = tester.element(find.byType(TranslateSheet));
      final l10n = context.l10n;
      expect(l10n.localeName, locale.toString());
      expect(find.text(l10n.translationTitle), findsOneWidget);
      expect(find.text(l10n.translationDetails), findsOneWidget);
      expect(
        find.text(l10n.translationAutoDetectedSource('English')),
        findsOne,
      );
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
    await _pumpTranslateSheet(tester, selection: _selection, service: service);
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
    await _pumpTranslateSheet(
      tester,
      selection: _selection,
      locale: const Locale('ar'),
      service: const _FakeTranslationService(includeLexicalDetails: true),
    );
    expect(_previewText(tester).textDirection, TextDirection.ltr);
    _expectSourceQuote(tester, _selectedFragmentFinder);
    _expectSourceQuote(tester, _previewFinder);
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
    await _pumpTranslateSheet(
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
    _expectSourceQuote(
      tester,
      _selectedFragmentFinder,
      direction: TextDirection.rtl,
    );
    _expectSourceQuote(tester, _previewFinder, direction: TextDirection.rtl);
    expect(
      _previewText(tester).textSpan!.toPlainText(),
      'توفر هذه البطارية الطاقة للأجهزة.',
    );
  });

  testWidgets('does not render raw service failure details', (tester) async {
    await _pumpTranslateSheet(
      tester,
      selection: _selection,
      service: const _FailingTranslationService(),
    );

    expect(find.text('Translation failed'), findsOneWidget);
    expect(
      find.text('Check the network connection or try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('credential leaked'), findsNothing);
    _expectSourceQuote(tester, _previewFinder);
  });
}

Future<void> _pumpTranslateSheet(
  WidgetTester tester, {
  required TextSelectionContext selection,
  ContextualTranslationService service = const _FakeTranslationService(),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  final preferences = await PreferencesService.create(
    supportedCodes: ReadflexSupportedLocales.codes,
  );
  addTearDown(preferences.dispose);
  await preferences.update(
    (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
  );

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: TranslateSheet(
          selection: selection,
          translationService: service,
          preferencesService: preferences,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _previewFinder =>
    find.byKey(const ValueKey('translation-selection-preview-text'));

Finder get _selectedFragmentFinder =>
    find.byKey(const ValueKey('translation-selected-fragment'));

Finder get _quoteSurfaceFinder => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).border is BorderDirectional,
);

void _expectSourceQuote(
  WidgetTester tester,
  Finder text, {
  TextDirection direction = TextDirection.ltr,
}) {
  final surface = find.ancestor(of: text, matching: _quoteSurfaceFinder);
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

Text _previewText(WidgetTester tester) => tester.widget<Text>(_previewFinder);

List<TextSpan> _previewSpans(WidgetTester tester) {
  final root = _previewText(tester).textSpan! as TextSpan;
  return root.children!.whereType<TextSpan>().toList(growable: false);
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  normalizedSelectedText: 'power',
  contextText: 'This power bank provides emergency power.',
  markedContextText: 'This [[power]] bank provides emergency power.',
  normalizedMarkedContextText: 'This [[power]] bank provides emergency power.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _paragraphSelection = TextSelectionContext(
  selectedText: 'Launches are mostly arbitrary these days.',
  contextText:
      'Before this point. Launches are mostly arbitrary these days. After it.',
  markedContextText:
      'Before this point. [[Launches are mostly arbitrary these days.]] '
      'After it.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

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

class _WordTranslationService implements ContextualTranslationService {
  _WordTranslationService(this.translation);

  final ContextualTranslationText translation;
  int calls = 0;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    calls++;
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      translation: translation,
    );
  }

  @override
  void dispose() {}
}

class _FakeTranslationService implements ContextualTranslationService {
  const _FakeTranslationService({
    this.includeLexicalDetails = false,
    this.alternativeCount = 1,
    this.primary,
  });

  final bool includeLexicalDetails;
  final int alternativeCount;
  final String? primary;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    final isTextTranslation = request.mode == selectedTextTranslationMode;
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      analysis: includeLexicalDetails
          ? const ContextualTranslationAnalysis(lemma: 'power')
          : null,
      translation: ContextualTranslationText(
        contextualTranslation:
            primary ??
            (isTextTranslation
                ? 'Запуски в наши дни в основном произвольны.'
                : includeLexicalDetails
                ? 'питание'
                : 'сила'),
        sentenceTranslation: includeLexicalDetails
            ? 'Этот аккумулятор обеспечивает аварийное питание.'
            : null,
      ),
      explanation: includeLexicalDetails ? 'Lexical explanation' : null,
      alternatives: includeLexicalDetails
          ? List.generate(
              alternativeCount,
              (index) => ContextualTranslationAlternative(
                translation: index == 0 ? 'релизы' : 'вариант ${index + 1}',
              ),
            )
          : const [],
    );
  }

  @override
  void dispose() {}
}

class _FailingTranslationService implements ContextualTranslationService {
  const _FailingTranslationService();

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
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

class _RecordingTranslationService extends _FakeTranslationService {
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
  }) async {
    sources.add(request.sourceLanguage);
    if (request.sourceLanguage == 'auto') {
      throw const ContextualTranslationException(
        ContextualTranslationFailureReason.sourceLanguageRequired,
        'Source required',
      );
    }
    return const _FakeTranslationService().translate(request);
  }

  @override
  void dispose() {}
}
