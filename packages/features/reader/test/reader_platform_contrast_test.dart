import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_selection_tip.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Cupertino selection tip keeps inverse actions readable $brightness',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          PlatformTestApp(
            platform: TargetPlatform.iOS,
            brightness: brightness,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderSelectionTipCard(onDismiss: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byType(ReaderSelectionTipCard);
        final context = tester.element(card);
        final plate = tester.widget<AppSurface>(
          find.descendant(of: card, matching: find.byType(AppSurface)),
        );
        final background = plate.color!;
        final action = find.text(context.l10n.readerSelectionTipDismiss);
        final foreground = DefaultTextStyle.of(
          tester.element(action),
        ).style.color!;
        expect(foreground, context.colors.inversePrimary);
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
        final title = tester.widget<Text>(
          find.text(context.l10n.readerSelectionTipTitle),
        );
        expect(
          _contrast(title.style!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
        final icon = tester.widget<Icon>(find.byIcon(AppIcons.translate));
        expect(_contrast(icon.color!, background), greaterThanOrEqualTo(3));
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
