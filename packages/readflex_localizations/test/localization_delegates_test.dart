import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  for (final locale in ReadflexSupportedLocales.locales) {
    testWidgets('loads standalone UI and app delegates for $locale', (
      tester,
    ) async {
      late MaterialLocalizations material;
      late ReadflexLocalizations app;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          home: Builder(
            builder: (context) {
              material = MaterialLocalizations.of(context);
              app = ReadflexLocalizations.of(context)!;
              return const Scaffold(body: TextField());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(app.localeName, startsWith(locale.languageCode));
      expect(material, isA<GlobalMaterialLocalizations>());
      expect(material.closeButtonTooltip, isNotEmpty);
      expect(material.selectAllButtonLabel, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
