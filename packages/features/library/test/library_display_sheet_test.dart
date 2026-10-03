import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_display_sheet.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_locale_cubit.dart';
import 'package:library_feature/src/library_theme_cubit.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferences;
  late LibraryLayoutCubit layout;
  late LibraryLocaleCubit locale;
  late LibraryThemeCubit theme;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    layout = LibraryLayoutCubit(preferencesService: preferences);
    locale = LibraryLocaleCubit(preferencesService: preferences);
    theme = LibraryThemeCubit(preferencesService: preferences);
    addTearDown(layout.close);
    addTearDown(locale.close);
    addTearDown(theme.close);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PreferencesScope(
        service: preferences,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: PreferencesScope.themeModeOf(context),
            locale: PreferencesScope.localeOf(context),
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reducedMotion,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showLibraryDisplaySheet(
                    context: context,
                    layoutCubit: layout,
                    localeCubit: locale,
                    themeCubit: theme,
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
  }

  final picker = find.byKey(const ValueKey('libraryLanguagePicker'));
  final russian = find.byKey(const ValueKey('libraryLanguageOption-ru'));

  testWidgets(
    'display ends at its content padding, not the language grid height',
    (
      tester,
    ) async {
      await open(tester);
      expect(
        tester.getBottomLeft(find.byType(ActionBottomSheetLayout)).dy -
            tester.getBottomLeft(picker).dy,
        closeTo(AppSpacing.lg, .01),
      );
      final sheet = tester.getRect(find.byType(BottomSheet));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(BottomSheet)), sheet);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('language slides inside one sheet at a stable height', (
    tester,
  ) async {
    await open(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    final heading = tester.getTopLeft(find.text('Display'));
    await tester.tap(picker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    expect(tester.getTopLeft(find.text('Display')).dx, lessThan(heading.dx));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    expect(picker.hitTestable(), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.ensureVisible(russian);
    await tester.tap(russian);
    await tester.pumpAndSettle();
    expect(russian.hitTestable(), findsOneWidget);
    expect(picker.hitTestable(), findsNothing);
    await tester.tap(find.byTooltip(tester.element(russian).l10n.commonBack));
    await tester.pumpAndSettle();
    expect(picker, findsOneWidget);
    expect(russian, findsNothing);
    expect(preferences.current.locale, const Locale('ru'));
    expect(find.text('Русский'), findsOneWidget);
    // Localized controls can wrap. The new height must still follow Display,
    // and opening Language must not stretch it.
    expect(
      tester.getBottomLeft(find.byType(ActionBottomSheetLayout)).dy -
          tester.getBottomLeft(picker).dy,
      closeTo(AppSpacing.lg, .01),
    );
    final localizedSheet = tester.getRect(find.byType(BottomSheet));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), localizedSheet);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back returns without a write; close dismisses the flow', (
    tester,
  ) async {
    await open(tester);
    for (final systemBack in [false, true]) {
      await tester.tap(picker);
      await tester.pumpAndSettle();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();
      expect(picker, findsOneWidget);
      expect(preferences.current.locale, const Locale('en'));
    }
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive language choices cannot take keyboard focus', (
    tester,
  ) async {
    await open(tester);
    final option = find.byKey(
      const ValueKey('libraryLanguageOption-en'),
      skipOffstage: false,
    );
    final label = find.descendant(
      of: option,
      matching: find.text('English', skipOffstage: false),
      skipOffstage: false,
    );
    expect(Focus.of(tester.element(label)).canRequestFocus, isFalse);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(label)).canRequestFocus, isTrue);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(label)).canRequestFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden display is neither interactive nor accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(picker.hitTestable(), findsNothing);
      expect(find.semantics.byLabel('View'), findsNothing);
      expect(find.semantics.byLabel('Display'), findsNothing);
      expect(Focus.of(tester.element(picker)).canRequestFocus, isFalse);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(picker.hitTestable(), findsOneWidget);
      expect(find.semantics.byLabel('View'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final drag in [false, true]) {
    testWidgets('language step handles ${drag ? 'drag' : 'scrim'} dismissal', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      if (drag) {
        final sheet = tester.getRect(find.byType(BottomSheet));
        await tester.dragFrom(
          Offset(sheet.center.dx, sheet.top + 10),
          const Offset(0, 450),
        );
      } else {
        await tester.tapAt(const Offset(12, 24));
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(preferences.current.locale, const Locale('en'));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('steps fit and retain height at $size / $scale', (
        tester,
      ) async {
        await open(tester, size: size, scale: scale);
        final sheet = tester.getRect(find.byType(BottomSheet));
        await tester.ensureVisible(picker);
        await tester.pumpAndSettle();
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(BottomSheet)), sheet);
        final back = tester.getRect(find.byTooltip('Back'));
        for (final language in ReadflexSupportedLocales.languages) {
          final option = find.byKey(
            ValueKey('libraryLanguageOption-${language.code}'),
          );
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          expect(tester.getRect(find.byTooltip('Back')), back);
        }
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(BottomSheet)), sheet);
        expect(picker.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('language changes apply immediately without leaving the picker', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    for (final code in ['en', 'ar', 'ru', 'en', 'en']) {
      final option = find.byKey(ValueKey('libraryLanguageOption-$code'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(preferences.current.locale, Locale(code));
      expect(option.hitTestable(), findsOneWidget);
      expect(picker.hitTestable(), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(of: option, matching: find.byIcon(AppIcons.check)),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(
        Directionality.of(tester.element(option)),
        code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final code in ['ru', 'ar']) {
    for (final exit in ['header back', 'system back', 'close']) {
      testWidgets('$exit keeps the chosen $code language', (tester) async {
        await open(tester);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        final option = find.byKey(ValueKey('libraryLanguageOption-$code'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget);
        final l10n = tester.element(option).l10n;
        final sheet = tester.getRect(find.byType(BottomSheet));
        if (exit == 'system back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(
            find
                .byTooltip(exit == 'close' ? l10n.commonClose : l10n.commonBack)
                .hitTestable(),
          );
        }
        if (exit == 'header back') {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final display = find.byType(ActionBottomSheetLayout).first;
          expect(
            tester.getRect(display).left,
            code == 'ar' ? greaterThan(sheet.left) : lessThan(sheet.left),
          );
        }
        await tester.pumpAndSettle();
        expect(preferences.current.locale, Locale(code));
        if (exit == 'close') {
          expect(find.byType(BottomSheet), findsNothing);
        } else {
          expect(picker.hitTestable(), findsOneWidget);
          expect(option, findsNothing);
          expect(tester.getRect(find.byType(BottomSheet)), sheet);
          await tester.tap(picker);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: option, matching: find.byIcon(AppIcons.check)),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('RTL motion mirrors and system back can interrupt it', (
    tester,
  ) async {
    await locale.setLocale(const Locale('ar'));
    await open(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    final display = find.byType(ActionBottomSheetLayout).first;
    await tester.tap(picker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(display).left, greaterThan(sheet.left));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(picker.hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    final rotatedSheet = tester.getRect(find.byType(BottomSheet));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), rotatedSheet);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches steps without a horizontal animation', (
    tester,
  ) async {
    await open(tester, reducedMotion: true);
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.tap(picker);
    await tester.pump();
    expect(picker.hitTestable(), findsNothing);
    expect(
      find.byKey(const ValueKey('libraryLanguageOption-en')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(picker.hitTestable(), findsOneWidget);
    expect(russian, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
