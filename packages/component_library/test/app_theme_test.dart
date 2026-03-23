import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    testWidgets('of() returns light theme in light mode', (tester) async {
      const light = LightAppThemeData();
      const dark = DarkAppThemeData();

      late AppThemeData result;

      await tester.pumpWidget(
        AppTheme(
          lightTheme: light,
          darkTheme: dark,
          child: MaterialApp(
            theme: light.materialThemeData,
            home: Builder(
              builder: (context) {
                result = AppTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(result, isA<LightAppThemeData>());
    });

    testWidgets('of() returns dark theme in dark mode', (tester) async {
      const light = LightAppThemeData();
      const dark = DarkAppThemeData();

      late AppThemeData result;

      await tester.pumpWidget(
        AppTheme(
          lightTheme: light,
          darkTheme: dark,
          child: MaterialApp(
            theme: dark.materialThemeData,
            home: Builder(
              builder: (context) {
                result = AppTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(result, isA<DarkAppThemeData>());
    });

    testWidgets('of() throws when no AppTheme ancestor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(() => AppTheme.of(context), throwsA(isA<FlutterError>()));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('LightAppThemeData', () {
    test('materialThemeData has light brightness', () {
      const theme = LightAppThemeData();
      expect(theme.materialThemeData.brightness, Brightness.light);
    });

    test('materialThemeData uses white scaffold color', () {
      const theme = LightAppThemeData();
      expect(
        theme.materialThemeData.scaffoldBackgroundColor,
        const Color(0xFFFFFFFF),
      );
    });
  });

  group('DarkAppThemeData', () {
    test('materialThemeData has dark brightness', () {
      const theme = DarkAppThemeData();
      expect(theme.materialThemeData.brightness, Brightness.dark);
    });

    test('materialThemeData uses space gray scaffold color', () {
      const theme = DarkAppThemeData();
      expect(
        theme.materialThemeData.scaffoldBackgroundColor,
        const Color(0xFF1C1C1E),
      );
    });
  });
}
