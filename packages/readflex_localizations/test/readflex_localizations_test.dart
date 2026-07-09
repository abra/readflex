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
