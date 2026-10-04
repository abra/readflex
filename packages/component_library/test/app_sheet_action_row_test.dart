import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('sheet actions share the header gutter ($direction)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var copied = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: ActionBottomSheetLayout.scrollable(
                title: 'Definition',
                closeLabel: 'Close',
                onClose: () {},
                bodyPadding: EdgeInsets.zero,
                child: AppSheetActionRow(
                  action: AppCopyButton(
                    onCopy: () async {
                      copied = true;
                    },
                    copyLabel: 'Copy',
                    copiedLabel: 'Copied',
                    failureLabel: 'Failed',
                  ),
                  child: const Text('Word'),
                ),
              ),
            ),
          ),
        ),
      );
      final copy = find.widgetWithIcon(IconButton, AppIcons.copy);
      final close = find.widgetWithIcon(IconButton, AppIcons.close);
      expect(tester.getSize(copy), const Size.square(48));
      expect(tester.getRect(copy).center.dx, tester.getRect(close).center.dx);
      final icon = tester.getRect(find.byIcon(AppIcons.copy));
      expect(direction == TextDirection.ltr ? 320 - icon.right : icon.left, 24);
      final bounds = tester.getRect(copy);
      await tester.tapAt(
        Offset(
          direction == TextDirection.ltr ? bounds.right - 1 : bounds.left + 1,
          bounds.center.dy,
        ),
      );
      await tester.pump();
      expect(copied, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
