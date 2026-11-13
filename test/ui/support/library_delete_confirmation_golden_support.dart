import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/readflex_platform_app.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../support/ui_test_app.dart';
import '../../support/ui_test_driver.dart';
import '../golden_support.dart';

void registerLibraryDeleteConfirmationGoldens({required bool arabic}) {
  setUpAll(() async {
    await loadUiFonts();
    // Native alert styles do not inherit the app's fallback families. Each
    // suite registers one portable system face in its own test process;
    // native SF typography is reviewed separately in OS screenshots.
    final font = arabic
        ? ByteData.sublistView(
            await File('test/fonts/NotoSansArabic.ttf').readAsBytes(),
          )
        : await rootBundle.load(
            'packages/component_library/fonts/Geist-Variable.ttf',
          );
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final (name, size, locale, scale, themeMode) in const [
      (
        'phone-light',
        Size(390, 844),
        Locale('en'),
        1.0,
        AppThemeMode.light,
      ),
      (
        'phone-dark',
        Size(390, 844),
        Locale('en'),
        1.0,
        AppThemeMode.dark,
      ),
      (
        'phone-de-large',
        Size(320, 568),
        Locale('de'),
        2.0,
        AppThemeMode.light,
      ),
      (
        'phone-ar-large',
        Size(390, 844),
        Locale('ar'),
        2.0,
        AppThemeMode.dark,
      ),
      (
        'tablet-wide',
        Size(1032, 1376),
        Locale('en'),
        1.0,
        AppThemeMode.light,
      ),
    ]) {
      if ((locale.languageCode == 'ar') != arabic) continue;
      final platformName = platform.name.toLowerCase();
      testWidgets('$platformName Library delete confirmation $name', (
        tester,
      ) async {
        final previousPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = platform;
        final native = platform == TargetPlatform.iOS;
        final tablet = AppWindowSize.isWideSize(size);
        final safeArea = FakeViewPadding(
          top: native ? (tablet ? 24 : 47) : 24,
          bottom: native ? (tablet ? 20 : 34) : 24,
        );
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1
          ..padding = safeArea
          ..viewPadding = safeArea;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = previousPlatform,
        );
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = (await tester.runAsync(UiTestApp.create))!;
        addTearDown(app.dispose);
        await tester.runAsync(() async {
          await app.bookRepository.markOpened(
            app.book!.id,
            DateTime(2026, 11, 12),
          );
          await app.bookRepository.updateReadingPosition(
            app.book!.id,
            cfi: null,
            progress: .42,
          );
          await app.preferencesService.update(
            (preferences) => preferences.copyWith(
              locale: locale,
              themeMode: themeMode,
            ),
          );
        });
        await tester.pumpWidget(
          RepaintBoundary(key: goldenBoundary, child: app.widget),
        );
        try {
          final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
          await waitForUi(
            tester,
            () => card.evaluate().isNotEmpty,
            description: 'Continue reading fixture',
          );
          await tester.pumpAndSettle();
          expect(find.byType(ReadflexPlatformApp), findsOneWidget);
          expect(
            find.byType(cupertino.CupertinoApp),
            native ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(material.MaterialApp),
            native ? findsNothing : findsOneWidget,
          );
          await tester.longPress(card);
          await tester.pumpAndSettle();
          await tapUi(
            tester,
            find.byKey(const ValueKey('libraryDeleteSelectedButton')),
          );
          await tester.pumpAndSettle();
          final dialog = find.byType(AppConfirmationDialog);
          expect(dialog, findsOneWidget);
          expect(
            find.byType(cupertino.CupertinoAlertDialog),
            native ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(material.AlertDialog),
            native ? findsNothing : findsOneWidget,
          );
          final context = tester.element(dialog);
          final strings = context.l10n;
          expect(
            Directionality.of(context),
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(find.text(strings.libraryDeleteItemsTitle(1)), findsOneWidget);
          expect(find.text(strings.libraryDeleteItemsBody(1)), findsOneWidget);
          for (final key in [
            AppConfirmationDialog.cancelButtonKey,
            AppConfirmationDialog.confirmButtonKey,
          ]) {
            final target = find.byKey(key);
            expect(target.hitTestable(), findsOneWidget);
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          }
          expect(tester.getSize(find.byKey(goldenBoundary)), size);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(goldenBoundary),
            matchesGoldenFile(
              'goldens/native-confirmation/$platformName/$name.png',
            ),
          );
          expect(tester.takeException(), isNull);
          await tapUi(
            tester,
            find.byKey(AppConfirmationDialog.cancelButtonKey),
          );
          await tester.pumpAndSettle();
          await waitForUi(
            tester,
            () => dialog.evaluate().isEmpty,
            description: 'confirmation route fully dismissed',
          );
          expect(dialog, findsNothing);
          expect(card, findsOneWidget);
          expect(
            find.byKey(const ValueKey('libraryCancelSelectionFab')),
            findsOneWidget,
          );
        } finally {
          await unmountUi(tester);
        }
      }, tags: ['golden']);
    }
  }
}
