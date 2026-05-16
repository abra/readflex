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

    test('light() uses dark system icons over light surfaces', () {
      final style = appSystemUiOverlayStyle(
        brightness: Brightness.light,
        backgroundColor: PrimitiveColors.gray50,
      );

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, PrimitiveColors.gray50);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    test('dark() uses light system icons over dark surfaces', () {
      final theme = AppTheme.dark();
      final style = theme.appBarTheme.systemOverlayStyle;

      expect(style?.statusBarColor, Colors.transparent);
      expect(style?.statusBarIconBrightness, Brightness.light);
      expect(style?.statusBarBrightness, Brightness.dark);
      expect(style?.systemNavigationBarColor, PrimitiveColors.darkGray900);
      expect(style?.systemNavigationBarIconBrightness, Brightness.light);
      expect(style?.systemStatusBarContrastEnforced, isFalse);
      expect(style?.systemNavigationBarContrastEnforced, isFalse);
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

    testWidgets('context.text exposes semantic app text roles', (tester) async {
      late AppTextTheme text;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              text = context.text;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(text.screenCounter.fontSize, text.labelSmall.fontSize);
      expect(text.sourceListTitle.fontSize, 14);
      expect(text.sourceMetadata.fontSize, 11);
      expect(text.sourceCoverBadge.fontSize, 8);
      expect(text.readerChromeLabel.fontSize, text.bodySmall.fontSize);
      expect(text.readerChromeNumber.fontFeatures, isNotEmpty);
      expect(text.kicker.fontSize, 10);
      expect(text.statusGlyph.fontSize, 22);
      expect(text.readerTextSizeControl(large: true).fontSize, 18);
      expect(text.readerTextSizeControl(large: false).fontSize, 14);
    });
  });
}
