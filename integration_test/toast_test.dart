import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    binding.reportData ??= {};
    binding.reportData!.addAll({
      'platform': Platform.operatingSystem,
      'tests': binding.results.map(
        (name, value) => MapEntry(name, value.toString()),
      ),
    });
  });

  testWidgets('native toast targets, localization, swipe and timeout', (
    tester,
  ) async {
    final app = await UiTestApp.create();
    addTearDown(app.dispose);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await waitForUi(
      tester,
      () => find.byType(FloatingActionButton).evaluate().isNotEmpty,
      description: 'Library',
    );
    for (final (locale, mode) in const [
      (Locale('en'), ThemeMode.light),
      (Locale('en'), ThemeMode.dark),
      (Locale('ar'), ThemeMode.dark),
    ]) {
      await app.preferencesService.update(
        (p) => p.copyWith(locale: locale, themeMode: mode),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FloatingActionButton));
      final strings = ReadflexLocalizations.of(context)!;
      final message = strings.librarySaveCollectionFailed;
      showToast(context, type: NotificationType.error, message: message);
      await tester.pump();
      await tester.pumpAndSettle();
      final close = find.widgetWithIcon(AppPlainIconButton, AppIcons.close);
      expect(close.hitTestable(), findsOneWidget);
      expect(tester.getSize(close), const Size.square(48));
      expect(
        find.byTooltip(MaterialLocalizations.of(context).closeButtonTooltip),
        findsOneWidget,
      );
      final name = 'toast-${locale.languageCode}-${mode.name}';
      if (Platform.isAndroid) {
        await captureAndroidScreenshot(name);
      } else {
        await binding.takeScreenshot(name);
      }
      await tester.tapAt(tester.getBottomRight(close) - const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);

      showToast(context, type: NotificationType.error, message: message);
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.drag(find.text(message), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    }
    final context = tester.element(find.byType(FloatingActionButton));
    final message = ReadflexLocalizations.of(context)!.commonCopied;
    showToast(context, type: NotificationType.success, message: message);
    await tester.pump();
    await waitForUi(
      tester,
      () => find.text(message).evaluate().isNotEmpty,
      description: 'success notification appears',
    );
    await waitForUi(
      tester,
      () => find.text(message).evaluate().isEmpty,
      description: 'success notification expires',
    );
    await unmountUi(tester);
  });
}
