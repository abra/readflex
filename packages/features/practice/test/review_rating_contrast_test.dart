import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/review_session_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final (emphasis, rating) in const [
      (ReviewRatingEmphasis.tonal, 'again'),
      (ReviewRatingEmphasis.tonal, 'hard'),
      (ReviewRatingEmphasis.tonal, 'good'),
      (ReviewRatingEmphasis.primary, 'good'),
      (ReviewRatingEmphasis.secondary, 'easy'),
    ]) {
      testWidgets(
        'Cupertino $emphasis $rating labels match their rendered fill $brightness',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            PlatformTestApp(
              platform: TargetPlatform.iOS,
              brightness: brightness,
              supportedLocales: ReadflexSupportedLocales.locales,
              localizationsDelegates: readflexLocalizationsDelegates,
              home: Center(
                child: SizedBox(
                  width: 240,
                  child: Builder(
                    builder: (context) => ReviewRatingButton(
                      label: 'Rating',
                      interval: const Duration(days: 3),
                      color: switch (rating) {
                        'again' => context.appColors.ratingAgain,
                        'hard' => context.appColors.ratingHard,
                        'easy' => context.appColors.ratingEasy,
                        _ => context.appColors.ratingGood,
                      },
                      emphasis: emphasis,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final nativeButton = find.byType(CupertinoButton);
          final context = tester.element(nativeButton);
          final decoration = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: nativeButton,
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((box) => box.decoration)
              .whereType<ShapeDecoration>()
              .first;
          final background = Color.alphaBlend(
            decoration.color!,
            context.colors.surface,
          );
          final labels = tester.widgetList<Text>(
            find.descendant(of: nativeButton, matching: find.byType(Text)),
          );
          expect(labels, hasLength(2));
          for (final label in labels) {
            expect(
              _contrast(label.style!.color!, background),
              greaterThanOrEqualTo(4.5),
              reason: '${label.data}: ${label.style!.color} on $background',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

double _contrast(Color foreground, Color background) {
  final ink = Color.alphaBlend(foreground, background).computeLuminance();
  final plate = background.computeLuminance();
  return (math.max(ink, plate) + .05) / (math.min(ink, plate) + .05);
}
