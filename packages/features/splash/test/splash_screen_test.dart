import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splash/splash.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('calls onFirstLaunch when no previous launch recorded', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      var firstLaunchCalled = false;
      var homeCalled = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          SplashScreen(
            onFirstLaunch: () => firstLaunchCalled = true,
            onHome: () => homeCalled = true,
          ),
        ),
      );

      // Wait for splash duration + async work.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(firstLaunchCalled, isTrue);
      expect(homeCalled, isFalse);
    });

    testWidgets('calls onHome when previous launch recorded', (tester) async {
      SharedPreferences.setMockInitialValues(
        {'readflex_first_launch_done': true},
      );

      var firstLaunchCalled = false;
      var homeCalled = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          SplashScreen(
            onFirstLaunch: () => firstLaunchCalled = true,
            onHome: () => homeCalled = true,
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(firstLaunchCalled, isFalse);
      expect(homeCalled, isTrue);
    });

    testWidgets('displays app name', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        _wrapWithTheme(
          SplashScreen(onFirstLaunch: () {}, onHome: () {}),
        ),
      );

      expect(find.text('Readflex'), findsOneWidget);

      // Let splash timer complete to avoid pending timer assertion.
      await tester.pumpAndSettle(const Duration(seconds: 2));
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
