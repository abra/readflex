import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  for (final profile in VisualProfile.values) {
    testWidgets('toast over Library ${profile.name}', (tester) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      tester.view.physicalSize = profile == VisualProfile.tabletRtl
          ? VisualProfile.phone.size
          : profile.size;
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
        description: 'Library',
      );
      final context = tester.element(find.byType(FloatingActionButton));
      final strings = ReadflexLocalizations.of(context)!;
      for (final type in NotificationType.values) {
        showToast(
          context,
          type: type,
          message: type == NotificationType.success
              ? ReadingFixture.bookTitle
              : strings.librarySaveCollectionFailed,
          messageSuffix: type == NotificationType.success
              ? strings.libraryDeletedSuffix
              : null,
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        final close = find.widgetWithIcon(AppPlainIconButton, AppIcons.close);
        final toast = find
            .ancestor(of: close, matching: find.byType(Material))
            .first;
        final toastRect = tester.getRect(toast);
        expect(toastRect.top, greaterThanOrEqualTo(AppSpacing.md));
        expect(toastRect.contains(tester.getTopLeft(close)), isTrue);
        expect(toastRect.contains(tester.getBottomRight(close)), isTrue);
        expect(tester.getSize(close), const Size.square(48));
        final suffix = profile == VisualProfile.tabletRtl ? '-phone-rtl' : '';
        await expectUiGolden(tester, profile, 'toast-${type.name}$suffix');
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();
      }
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
