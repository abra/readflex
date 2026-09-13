import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('library and display ${profile.name}', (tester) async {
      final app = await tester.runAsync(() => UiTestApp.create());
      addTearDown(app!.dispose);
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app.preferencesService.update(
        (p) => p.copyWith(
          locale: profile.locale,
          themeMode: profile.brightness == Brightness.light
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widget),
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'library ready for snapshot',
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'library-grid');
      final strings = ReadflexLocalizations.of(
        tester.element(find.byType(LibraryScreen)),
      )!;
      await tapUi(tester, find.byTooltip(strings.libraryDisplayOptions));
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'library-display');
      await dismissSheet(tester);
      await tester.enterText(find.byType(TextField), 'no matching title');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await expectUiGolden(tester, profile, 'library-no-results');
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
