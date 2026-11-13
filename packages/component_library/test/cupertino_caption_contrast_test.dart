import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/platform_test_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'Cupertino small captions retain contrast on every surface $brightness',
      () {
        final adapter = AppTheme.forPlatform(TargetPlatform.iOS, brightness);
        final theme = AppTheme.dataFor(adapter);
        final foreground = theme.colors.onSurfaceVariant;
        final native = brightness == Brightness.dark
            ? CupertinoColors.secondaryLabel.darkColor
            : CupertinoColors.secondaryLabel.color;
        expect(foreground.withValues(alpha: 1), native.withValues(alpha: 1));
        expect(foreground.a, closeTo(.8, .001));
        final surfaces = {
          'background': theme.backgroundColor,
          'sheet': theme.sheetColor,
          'surface': theme.colors.surface,
          'lowest': theme.colors.surfaceContainerLowest,
          'low': theme.colors.surfaceContainerLow,
          'container': theme.colors.surfaceContainer,
          'high': theme.colors.surfaceContainerHigh,
          'highest': theme.colors.surfaceContainerHighest,
        };
        for (final surface in surfaces.entries) {
          final background = Color.alphaBlend(
            surface.value,
            theme.backgroundColor,
          );
          expect(
            _contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '${surface.key}: $foreground on $background',
          );
        }
      },
    );

    testWidgets(
      'Cupertino section title uses the readable caption role $brightness',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          PlatformTestApp(
            platform: TargetPlatform.iOS,
            brightness: brightness,
            home: const Center(
              child: AppSheetSection(title: 'Caption', child: Text('Body')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text('Caption');
        final context = tester.element(title);
        final foreground = tester.widget<Text>(title).style!.color!;
        final background = Color.alphaBlend(
          AppSurfaceAppearance.resolve(context, AppSurfaceRole.field).color,
          context.appTheme.sheetColor,
        );
        expect(foreground, context.colors.onSurfaceVariant);
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

double _contrast(Color foreground, Color background) {
  final ink = Color.alphaBlend(foreground, background).computeLuminance();
  final plate = background.computeLuminance();
  return (math.max(ink, plate) + .05) / (math.min(ink, plate) + .05);
}
