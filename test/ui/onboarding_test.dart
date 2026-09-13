import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  for (final skip in [false, true]) {
    testWidgets('first launch completes and stays completed (skip=$skip)', (
      tester,
    ) async {
      final app = await tester.runAsync(
        () => UiTestApp.create(
          onboardingCompleted: false,
          withBook: false,
        ),
      );
      addTearDown(app!.dispose);
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      if (skip) {
        await tapUi(tester, find.text('Skip'));
      } else {
        await tapUi(tester, find.text('Next'));
        await tapUi(tester, find.text('Next'));
        await tapUi(tester, find.text('Get Started'));
      }
      await waitForUi(
        tester,
        () => find.byType(LibraryScreen).evaluate().isNotEmpty,
        description: 'onboarding opens library',
      );
      expect(app.preferencesService.current.onboardingCompleted, isTrue);
      await unmountUi(tester);
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
      await unmountUi(tester);
    });
  }

  for (final profile in VisualProfile.values) {
    testWidgets('onboarding pages ${profile.name}', (tester) async {
      var completed = false;
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => OnboardingScreen(
          onComplete: () => completed = true,
        ),
      );
      final strings = ReadflexLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      )!;
      var scrolled = false;
      for (var page = 0; page < 3; page++) {
        await expectUiGolden(tester, profile, 'onboarding-$page');
        if (profile == VisualProfile.largeText) {
          final content = find.byType(SingleChildScrollView).hitTestable();
          final position = tester
              .state<ScrollableState>(
                find.descendant(of: content, matching: find.byType(Scrollable)),
              )
              .position;
          if (position.maxScrollExtent > 0) {
            await tester.drag(content, const Offset(0, -1000));
            await tester.pumpAndSettle();
            expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
            scrolled = true;
          }
        }
        final next = find.text(
          page == 2 ? strings.appGetStarted : strings.appNext,
        );
        expect(next.hitTestable(), findsOneWidget);
        await tapUi(
          tester,
          next,
        );
      }
      if (profile == VisualProfile.largeText) expect(scrolled, isTrue);
      expect(completed, isTrue);
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
