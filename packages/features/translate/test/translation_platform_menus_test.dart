import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoListTile, CupertinoPopupSurface;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MenuItemButton;
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/translate_sheet_harness.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform translation opens nested language menus and '
        'expands details without replacing its sheet', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final preferences = await PreferencesService.create(
        supportedCodes: ReadflexSupportedLocales.codes,
      );
      addTearDown(preferences.dispose);
      await preferences.update(
        (value) => value.copyWith(translationTargetLanguageCode: 'ru'),
      );
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          home: Builder(
            builder: (context) => Center(
              child: AppButton(
                onPressed: () => showTranslateSheet(
                  context,
                  selection: powerSelection,
                  translationService: const FakeTranslationService(
                    includeLexicalDetails: true,
                  ),
                  preferencesService: preferences,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheet = tester.element(find.byType(TranslateSheet));
      final l10n = sheet.l10n;
      final details = find.text(l10n.translationDetails);
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Lexical explanation'), findsOneWidget);
      for (final (key, option) in [
        ('translation-target-language', 'Deutsch'),
        ('translation-source-language', 'English'),
      ]) {
        final trigger = find.byKey(ValueKey(key));
        await tester.ensureVisible(trigger);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(CupertinoPopupSurface), findsNWidgets(2));
        }
        final choice = platform == TargetPlatform.iOS
            ? find.widgetWithText(CupertinoListTile, option)
            : find.widgetWithText(MenuItemButton, option);
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(TranslateSheet)), same(sheet));
        expect(tester.takeException(), isNull);
      }
      expect(preferences.current.translationTargetLanguageCode, 'de');
      await tester.tap(find.byTooltip(l10n.commonClose).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(TranslateSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
