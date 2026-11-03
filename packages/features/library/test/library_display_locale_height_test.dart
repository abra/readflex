import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_display_sheet.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_locale_cubit.dart';
import 'package:library_feature/src/library_page_animation_cubit.dart';
import 'package:library_feature/src/library_theme_cubit.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Geist')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Geist-Variable.ttf',
          ),
        ))
        .load();
  });

  testWidgets('440dp language changes keep the active picker height while '
      'localized Display adopts its natural height on Back', (tester) async {
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    final layout = LibraryLayoutCubit(preferencesService: preferences);
    final locale = LibraryLocaleCubit(preferencesService: preferences);
    final theme = LibraryThemeCubit(preferencesService: preferences);
    final animation = LibraryPageAnimationCubit(
      preferencesService: preferences,
    );
    addTearDown(preferences.dispose);
    addTearDown(layout.close);
    addTearDown(locale.close);
    addTearDown(theme.close);
    addTearDown(animation.close);
    await tester.pumpWidget(
      PreferencesScope(
        service: preferences,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light(),
            locale: PreferencesScope.localeOf(context),
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            supportedLocales: ReadflexSupportedLocales.locales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showLibraryDisplaySheet(
                    context: context,
                    layoutCubit: layout,
                    localeCubit: locale,
                    themeCubit: theme,
                    pageAnimationCubit: animation,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final original = tester.getRect(sheet);
    await tester.tap(find.byKey(const ValueKey('libraryLanguagePicker')));
    await tester.pumpAndSettle();
    for (final code in ['ru', 'ar', 'en', 'ru']) {
      final option = find.byKey(ValueKey('libraryLanguageOption-$code'));
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(preferences.current.locale, Locale(code));
      expect(tester.getRect(sheet), original, reason: 'active Language: $code');
      expect(option.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: option, matching: find.byIcon(AppIcons.check)),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(option)),
        code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      final hiddenDisplayLanguage = find.byKey(
        const ValueKey('libraryLanguagePicker'),
        skipOffstage: false,
      );
      expect(
        find.descendant(
          of: hiddenDisplayLanguage,
          matching: find.text('English', skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    final russian = find.byKey(const ValueKey('libraryLanguageOption-ru'));
    await tester.tap(find.byTooltip(tester.element(russian).l10n.commonBack));
    await tester.pumpAndSettle();
    expect(find.text('Оформление'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(tester.getRect(sheet).height, closeTo(original.height + 112, .01));
    await tester.tap(find.byKey(const ValueKey('libraryLanguagePicker')));
    await tester.pumpAndSettle();
    expect(tester.getRect(sheet).height, closeTo(original.height + 112, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
