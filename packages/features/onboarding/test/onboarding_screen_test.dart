import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding/onboarding.dart';

void main() {
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

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Practice & remember'), findsOneWidget);
    });

    testWidgets('Get Started calls onComplete', (tester) async {
      var completed = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          OnboardingScreen(onComplete: () => completed = true),
        ),
      );

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
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

      expect(find.byType(AnimatedContainer), findsNWidgets(5));
    });
  });
}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: child,
  );
}
