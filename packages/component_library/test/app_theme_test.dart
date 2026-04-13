import 'package:component_library/component_library.dart';
import 'package:component_library/src/theme/tokens/primitive_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('light() returns ThemeData with light brightness', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
    });

    test('dark() returns ThemeData with dark brightness', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
    });

    test('light() uses correct scaffold color', () {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, PrimitiveColors.gray50);
    });

    test('dark() uses correct scaffold color', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, PrimitiveColors.darkGray900);
    });

    test('light() includes AppColorsExt extension', () {
      final theme = AppTheme.light();
      expect(theme.extension<AppColorsExt>(), isNotNull);
    });

    test('dark() includes AppColorsExt extension', () {
      final theme = AppTheme.dark();
      expect(theme.extension<AppColorsExt>(), isNotNull);
    });

    testWidgets('Theme.of(context).ext returns AppColorsExt', (tester) async {
      late AppColorsExt result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              result = Theme.of(context).ext;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, isA<AppColorsExt>());
    });
  });
}
