import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/app_system_ui_mode.dart';
import 'package:readflex/app/reader_system_navigation_bar_mode.dart';

void main() {
  const reader = SizedBox(key: Key('reader'));

  testWidgets(
    'Android hides only the bottom system overlay around the reader',
    (tester) async {
      await tester.pumpWidget(
        const ReaderSystemNavigationBarMode(child: reader),
      );

      final overlay = tester.widget<AppBottomSystemOverlayVisibility>(
        find.byType(AppBottomSystemOverlayVisibility),
      );
      expect(overlay.visible, isFalse);
      expect(
        find.descendant(
          of: find.byType(AppBottomSystemOverlayVisibility),
          matching: find.byKey(const Key('reader')),
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'other platforms keep their system UI',
    (tester) async {
      await tester.pumpWidget(
        const ReaderSystemNavigationBarMode(child: reader),
      );

      expect(find.byType(AppBottomSystemOverlayVisibility), findsNothing);
      expect(find.byKey(const Key('reader')), findsOneWidget);
    },
    variant: TargetPlatformVariant(
      TargetPlatform.values.toSet()..remove(TargetPlatform.android),
    ),
  );
}
