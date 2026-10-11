import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  test('keeps the supported locale list in the app-defined order', () {
    expect(ReadflexSupportedLocales.codes, [
      'en',
      'zh',
      'hi',
      'es',
      'ar',
      'fr',
      'ru',
      'pt',
      'de',
      'ja',
    ]);
  });

  test('loads generated localizations for every supported locale', () {
    for (final locale in ReadflexSupportedLocales.locales) {
      final l10n = lookupReadflexLocalizations(locale);

      expect(l10n.commonSave, isNotEmpty);
      expect(l10n.libraryTitle, isNotEmpty);
      expect(l10n.readerSearchFailed, isNotEmpty);
    }
  });

  group('selection copy', () {
    for (final locale in ReadflexSupportedLocales.locales) {
      test('names the real selection menu labels: $locale', () {
        final l10n = lookupReadflexLocalizations(locale);
        final translate = l10n.translationAction;
        final define = l10n.dictionaryAction;
        final copy = l10n.commonCopy;
        final highlight = l10n.highlightAction;

        final lookup = l10n.onboardingFeatureLookupDescription(
          translate,
          define,
        );
        expect(lookup, allOf(contains(translate), contains(define)));

        final tip = l10n.readerSelectionTipBody(
          highlight,
          copy,
          translate,
          define,
        );
        final order = [
          highlight,
          copy,
          translate,
          define,
        ].map(tip.indexOf).toList();
        expect(order, everyElement(isNonNegative), reason: tip);
        expect(order, orderedEquals([...order]..sort()), reason: tip);

        final sample = l10n.onboardingSelectionSampleLabel(
          copy,
          translate,
          define,
        );
        expect(
          sample,
          allOf(contains(copy), contains(translate), contains(define)),
        );
      });

      test('the sample sentence holds its selected word once: $locale', () {
        final l10n = lookupReadflexLocalizations(locale);
        final word = l10n.onboardingSelectionSampleWord;
        final sentence = l10n.onboardingSelectionSampleSentence(word);

        expect(word.trim(), isNotEmpty);
        expect(sentence.indexOf(word), isNonNegative);
        expect(sentence.indexOf(word), sentence.lastIndexOf(word));
        expect(sentence.length, greaterThan(word.length));
      });

      test('the same-language copy names the language and Define: '
          '$locale', () {
        final l10n = lookupReadflexLocalizations(locale);
        const language = 'English';
        expect(l10n.translationSameLanguageTitle.trim(), isNotEmpty);
        expect(l10n.translationSameLanguageBody(language), contains(language));
        final define = l10n.translationSameLanguageDefineBody(
          language,
          l10n.dictionaryAction,
        );
        expect(
          define,
          allOf(contains(language), contains(l10n.dictionaryAction)),
        );
      });

      test('the welcome copy keeps the app name: $locale', () {
        final l10n = lookupReadflexLocalizations(locale);
        expect(l10n.onboardingWelcomeTitle, contains('Readflex'));
        expect(l10n.onboardingFeatureBooksDescription, contains('EPUB'));
        expect(l10n.onboardingFeatureBooksDescription, contains('CBZ'));
        expect(l10n.readerSelectionTipDismiss.trim(), isNotEmpty);
      });
    }
  });

  test('uses Russian highlight terminology consistently', () {
    final l10n = lookupReadflexLocalizations(const Locale('ru'));

    expect(l10n.highlightAction, 'Выделить');
    expect(l10n.highlightTitle, 'Выделение');
    expect(l10n.readerHighlights, 'Выделения');
    expect(l10n.readerHighlightSaved, 'Выделение сохранено');
    expect(l10n.readerHighlightRemoved, 'Выделение удалено');
    expect(l10n.highlightFailedToSave, 'Не удалось сохранить выделение');
    expect(l10n.readerHighlightSaveFailed, l10n.highlightFailedToSave);
    expect(l10n.highlightColorSemantics('Желтый'), 'Желтый цвет выделения');
    expect(l10n.highlightSelectColor, 'Выбрать цвет выделения');
    expect(l10n.readerSearchHighlights, 'Поиск выделений');
    expect(l10n.readerNoHighlightsYet, 'Выделений пока нет');
    expect(l10n.readerNoMatchingHighlights, 'Подходящих выделений нет');
    expect(l10n.readerRemoveHighlight, 'Удалить выделение');
    expect(l10n.readerHighlightNoteTitle, 'Заметка к выделению');
    expect(l10n.onboardingFeatureHighlightsTitle, 'Выделения и заметки');
    // "Выделить" is the highlight command, so the selection copy never asks
    // the reader to "выделить" a word.
    for (final copy in [
      l10n.onboardingFeatureLookupDescription('A', 'B'),
      l10n.readerSelectionTipTitle,
    ]) {
      expect(copy.toLowerCase(), isNot(contains('выдел')), reason: copy);
    }
    for (final count in [1, 2, 5, 21]) {
      expect(l10n.libraryDeleteItemsBody(count), contains('выделения'));
      expect(
        l10n.libraryDeleteItemsBody(count),
        isNot(contains('Архивные учебные данные сохранятся.')),
      );
    }
  });

  testWidgets('exposes delegates through MaterialApp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Text(context.l10n.libraryTitle),
        ),
      ),
    );

    expect(find.text('Библиотека'), findsOneWidget);
  });
}
