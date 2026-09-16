import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

void main() {
  testWidgets(
    'theme and locale changes retain router, route and library load',
    (tester) async {
      final app = await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      );
      addTearDown(app!.dispose);
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      router.go(AppRoutes.onboarding);
      await tester.pumpAndSettle();
      final reads = app.bookRepository.reads;

      await tester.runAsync(
        () => app.preferencesService.update(
          (prefs) => prefs.copyWith(
            themeMode: ThemeMode.dark,
            locale: const Locale('de'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.routerConfig, same(router));
      expect(materialApp.themeMode, ThemeMode.dark);
      expect(materialApp.locale, const Locale('de'));
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.onboarding,
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(app.bookRepository.reads, reads);
      await unmountUi(tester);
    },
  );
}
