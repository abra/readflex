import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex/app/screens/onboarding_page_data.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  testWidgets('reduced motion and RTL apply to onboarding controls', (
    tester,
  ) async {
    await pumpGoldenSurface(
      tester,
      VisualProfile.tabletRtl,
      (_) => OnboardingScreen(onComplete: () {}),
      surfaceSize: const Size(390, 844),
    );
    final strings = ReadflexLocalizations.of(
      tester.element(find.byType(OnboardingScreen)),
    )!;
    expect(tester.getCenter(find.text(strings.appSkip)).dx, lessThan(195));
    await tester.tap(find.text(strings.appNext));
    await tester.pump();
    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.controller!.page, 1);
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .every((w) => w.duration == Duration.zero),
      isTrue,
    );
  });

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
        final strings = ReadflexLocalizations.of(
          tester.element(find.byType(OnboardingScreen)),
        )!;
        final pages = onboardingPages(strings);
        for (var page = 1; page < pages.length; page++) {
          expect(find.text(strings.appGetStarted), findsNothing);
          await tapUi(tester, find.text(strings.appNext));
        }
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
      final pages = onboardingPages(strings);
      for (var page = 0; page < pages.length; page++) {
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          page,
        );
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
          page == pages.length - 1 ? strings.appGetStarted : strings.appNext,
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

  testWidgets('page body and primary action share the 16dp gutter', (
    tester,
  ) async {
    await pumpGoldenSurface(
      tester,
      VisualProfile.phone,
      (_) => OnboardingScreen(onComplete: () {}),
      surfaceSize: const Size(390, 844),
    );
    final body = tester.getRect(find.byType(SingleChildScrollView).first);
    final button = tester.getRect(find.byType(FilledButton));
    expect(body.left, AppSpacing.lg);
    expect(body.right, 390 - AppSpacing.lg);
    expect(button.left, body.left);
    expect(button.right, body.right);
  });

  testWidgets('page changes use the medium motion token', (tester) async {
    await pumpGoldenSurface(
      tester,
      VisualProfile.phone,
      (_) => OnboardingScreen(onComplete: () {}),
      surfaceSize: const Size(390, 844),
    );
    final strings = ReadflexLocalizations.of(
      tester.element(find.byType(OnboardingScreen)),
    )!;
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .every((w) => w.duration == Duration.zero),
      isTrue,
      reason: 'golden surfaces disable animations',
    );
    await tester.tap(find.text(strings.appNext));
    await tester.pump();
    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.controller!.page, 1);
  });
}
