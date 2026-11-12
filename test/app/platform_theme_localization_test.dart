import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:readflex/app/readflex_platform_app.dart';

void main() {
  for (final locale in [
    const Locale('en'),
    const Locale('de'),
    const Locale('ar'),
  ]) {
    testWidgets('Material semantic text keeps localized geometry for $locale', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        ReadflexPlatformApp(
          locale: locale,
          home: const AppScaffold(body: Text('Text geometry')),
        ),
      );
      final context = tester.element(find.text('Text geometry'));
      final native = material.Theme.of(context).textTheme;
      expect(context.text.bodyMedium, native.bodyMedium);
      expect(context.text.bodySmall, native.bodySmall);
      expect(context.text.titleSmall, native.titleSmall);
      expect(context.text.labelLarge, native.labelLarge);
      expect(
        IconTheme.of(context).color,
        material.Theme.of(context).iconTheme.color,
      );
    });
  }

  testWidgets('Cupertino semantic text uses native type roles', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      const ReadflexPlatformApp(
        home: AppScaffold(body: Text('Native type')),
      ),
    );
    final context = tester.element(find.text('Native type'));
    expect(context.text.bodyLarge.fontFamily, 'CupertinoSystemText');
    expect(context.text.bodyLarge.fontSize, 17);
    expect(context.text.titleMedium.fontSize, 17);
    expect(context.text.headlineLarge.fontSize, 34);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Cupertino filled action has readable contrast in $brightness',
      (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(
          ReadflexPlatformApp(
            brightness: brightness,
            home: const AppScaffold(body: Text('Action palette')),
          ),
        );
        final colors = tester.element(find.text('Action palette')).colors;
        final a = colors.primary.computeLuminance();
        final b = colors.onPrimary.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        final native = AppTheme.cupertino(
          AppTheme.forPlatform(TargetPlatform.iOS, brightness),
        );
        expect(native.primaryColor, colors.primary);
        expect(native.primaryContrastingColor, colors.onPrimary);
      },
    );
  }
}
