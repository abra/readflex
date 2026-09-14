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
    expect(
      l10n.onboardingHighlightSaveDescription,
      'Сохраняйте выделенные фрагменты текста и добавляйте заметки.',
    );
    for (final count in [1, 2, 5, 21]) {
      expect(l10n.libraryDeleteItemsBody(count), contains('ваши выделения'));
      expect(
        l10n.libraryDeleteItemsBody(count),
        contains('Архивные учебные данные сохранятся.'),
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
