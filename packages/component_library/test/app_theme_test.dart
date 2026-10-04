import 'package:component_library/component_library.dart';
import 'package:component_library/src/theme/tokens/primitive_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      test('text roles retain contrast in ${theme.brightness.name}', () {
        final colors = theme.colorScheme;
        final surfaces = {
          'surface': colors.surface,
          'sheet': colors.surfaceContainerLow,
          'input': colors.surfaceContainerHighest,
        };
        for (final foreground in {
          'onSurface': colors.onSurface,
          'onSurfaceVariant': colors.onSurfaceVariant,
        }.entries) {
          for (final background in surfaces.entries) {
            _expectTextContrast(
              foreground.value,
              background.value,
              '${foreground.key} on ${background.key}',
            );
          }
        }
        for (final pair in [
          (
            theme.inputDecorationTheme.hintStyle!.color!,
            theme.inputDecorationTheme.fillColor!,
            'input hint',
          ),
          (colors.onPrimary, colors.primary, 'primary button'),
          (colors.onSecondary, colors.secondary, 'secondary control'),
          (colors.onError, colors.error, 'destructive button'),
          (
            theme.ext.onSuccessContainer,
            theme.ext.successContainer,
            'success notification',
          ),
        ]) {
          _expectTextContrast(pair.$1, pair.$2, pair.$3);
        }
      });
    }

    test('light() returns ThemeData with light brightness', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
    });

    test('success color pair survives theme copying and interpolation', () {
      final light = AppTheme.light().ext;
      final dark = AppTheme.dark().ext;
      final copied = light.copyWith() as AppColorsExt;
      expect(copied.successContainer, light.successContainer);
      expect(copied.onSuccessContainer, light.onSuccessContainer);
      final overridden =
          light.copyWith(
                successContainer: dark.successContainer,
                onSuccessContainer: dark.onSuccessContainer,
              )
              as AppColorsExt;
      expect(overridden.successContainer, dark.successContainer);
      expect(overridden.onSuccessContainer, dark.onSuccessContainer);
      final interpolated = light.lerp(dark, .5) as AppColorsExt;
      expect(
        interpolated.successContainer,
        Color.lerp(light.successContainer, dark.successContainer, .5),
      );
      expect(
        interpolated.onSuccessContainer,
        Color.lerp(light.onSuccessContainer, dark.onSuccessContainer, .5),
      );
    });

    test('dark() returns ThemeData with dark brightness', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
    });

    test('button themes explicitly use the app sans font', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
        ]) {
          expect(
            style!.textStyle!.resolve({})!.fontFamily,
            AppTypography.fontFamilySans,
          );
          expect(
            style.textStyle!.resolve({})!.fontFamilyFallback,
            AppTypography.fontFamilyFallback,
          );
        }
        expect(
          theme.textTheme.bodyLarge!.fontFamilyFallback,
          AppTypography.fontFamilyFallback,
        );
        expect(
          theme.textTheme.headlineSmall!.fontFamily,
          AppTypography.fontFamilySerif,
        );
      }
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
    });
  });
}

void _expectTextContrast(Color foreground, Color background, String role) {
  final text = Color.alphaBlend(foreground, background).computeLuminance();
  final surface = background.computeLuminance();
  final ratio = text > surface
      ? (text + .05) / (surface + .05)
      : (surface + .05) / (text + .05);
  expect(ratio, greaterThanOrEqualTo(4.5), reason: role);
}
