import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splash/splash.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('calls onReady after splash duration', (tester) async {
      var readyCalled = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          SplashScreen(onReady: () => readyCalled = true),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(readyCalled, isTrue);
    });

    testWidgets('displays app name', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(SplashScreen(onReady: () {})),
      );

      expect(find.text('Readflex'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 2));
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
