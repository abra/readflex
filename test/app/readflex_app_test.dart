import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:library_feature/library_feature.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

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

  for (final addBook in [false, true]) {
    testWidgets(
      'first launch: ${addBook ? 'Add a book' : 'Not now'} completes '
      'onboarding once and for all',
      (tester) async {
        final app = await tester.runAsync(
          () => UiTestApp.create(onboardingCompleted: false, withBook: false),
        );
        addTearDown(app!.dispose);
        await tester.pumpWidget(app.widget);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);
        final l10n = ReadflexLocalizations.of(
          tester.element(find.byType(OnboardingScreen)),
        )!;

        await tapUi(
          tester,
          addBook
              ? find.widgetWithText(FilledButton, l10n.onboardingAddBook)
              : find.widgetWithText(TextButton, l10n.onboardingNotNow),
        );
        await waitForUi(
          tester,
          // The onboarding page stays mounted until the route transition ends.
          () =>
              app.preferencesService.current.onboardingCompleted &&
              find.byType(LibraryScreen).evaluate().isNotEmpty &&
              find.byType(OnboardingScreen).evaluate().isEmpty,
          description: 'onboarding completes into the library',
        );
        if (addBook) {
          // Add a book continues into the import sheet over the library.
          await waitForUi(
            tester,
            () => find.byType(BottomSheet).evaluate().isNotEmpty,
            description: 'import sheet opens',
          );
          // Close it so the remount below starts from a settled Library.
          await tapUi(tester, find.byTooltip(l10n.commonClose));
          expect(find.byType(BottomSheet), findsNothing);
        } else {
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
        }

        await unmountUi(tester);
        await tester.pumpWidget(app.widget);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LibraryScreen), findsOneWidget);
        await unmountUi(tester);
      },
    );
  }
}
