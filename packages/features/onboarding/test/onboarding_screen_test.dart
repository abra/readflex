import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding/onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingScreen', () {
    testWidgets('displays first page on launch', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () {}),
        ),
      );

      expect(find.text('Read anything'), findsOneWidget);
    });

    testWidgets('Next button advances to next page', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () {}),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Highlight & save'), findsOneWidget);
    });

    testWidgets('shows Get Started on last page', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () {}),
        ),
      );

      // Navigate to last page (tap Next 4 times).
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Practice & remember'), findsOneWidget);
    });

    testWidgets('Get Started calls onComplete and saves preference', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () => completed = true),
        ),
      );

      // Navigate to last page.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('readflex_first_launch_done'), isTrue);
    });

    testWidgets('Skip calls onComplete', (tester) async {
      var completed = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () => completed = true),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('displays 5 page indicators', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () {}),
        ),
      );

      // 5 AnimatedContainer indicators.
      expect(find.byType(AnimatedContainer), findsNWidgets(5));
    });
  });
}

Widget _wrapWithTheme(Widget child) {
  const light = LightAppThemeData();
  const dark = DarkAppThemeData();

  return MaterialApp(
    theme: light.materialThemeData,
    darkTheme: dark.materialThemeData,
    home: AppTheme(lightTheme: light, darkTheme: dark, child: child),
  );
}
