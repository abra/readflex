import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final direction in TextDirection.values) {
      testWidgets('short chip has horizontal and vertical tap padding: '
          '${platform.name}/$direction', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light().copyWith(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(size: Size(390, 844)),
                  child: Directionality(
                    textDirection: direction,
                    child: Center(
                      child: AppFilterChip(
                        label: 'I',
                        selected: true,
                        onTap: () => calls++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final chip = find.byType(AppFilterChip);
          final target = tester.getRect(chip);
          final body = tester.getRect(
            find.descendant(of: chip, matching: find.byType(AppSurface)),
          );
          expect(target.size, const Size(48, 48));
          expect(body.height, AppSizes.chipHeight);
          expect(body.width, lessThan(target.width));
          expect(
            tester.getSemantics(chip),
            matchesSemantics(
              label: 'I',
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              hasTapAction: true,
            ),
          );
          final left = Offset(target.left + 1, target.center.dy);
          final right = Offset(target.right - 1, target.center.dy);
          final top = Offset(target.center.dx, target.top + 1);
          expect(body.contains(left), isFalse);
          expect(body.contains(right), isFalse);
          expect(body.contains(top), isFalse);
          for (final position in [left, right, top, body.center]) {
            await tester.tapAt(position);
          }
          expect(calls, 4, reason: 'each padding/body tap invokes one action');
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets(
    'label and count follow the medium window without enlarging phones',
    (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final chip = AppFilterChip(
        label: 'All',
        count: 12,
        selected: false,
        onTap: () {},
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Center(child: chip)),
        ),
      );
      for (final (size, fontSize) in const [
        (Size(390, 844), 12.0),
        (Size(599, 900), 12.0),
        (Size(600, 479), 12.0),
        (Size(600, 480), 15.0),
        (Size(800, 1280), 15.0),
        (Size(844, 390), 12.0),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.widget<Text>(find.text('All')).style!.fontSize, fontSize);
        expect(tester.widget<Text>(find.text('12')).style!.fontSize, fontSize);
        final target = tester.getSize(find.byType(AppFilterChip));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'long 200% labels wrap inside bounded medium chips: $direction',
      (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final label = direction == TextDirection.rtl
              ? 'العبارات المحفوظة للتعلّم'
              : 'Gespeicherte Markierungen';
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(800, 1280),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Center(
                      child: SizedBox(
                        width: 220,
                        child: AppFilterChip(
                          label: label,
                          count: 3,
                          selected: false,
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final chip = find.byType(AppFilterChip);
          final target = tester.getRect(chip);
          final text = tester.widget<Text>(find.text(label));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(target.width, 220);
          expect(target.height, greaterThan(48));
          expect(
            text.style!.fontSize,
            AppTheme.light().textTheme.labelLarge!.fontSize,
          );
          expect(paragraph.textScaler.scale(text.style!.fontSize!), 30);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(text.overflow, isNull);
          expect(target.contains(tester.getTopLeft(find.text(label))), isTrue);
          expect(
            tester.getRect(find.text(label)).right,
            lessThanOrEqualTo(target.right),
          );
          expect(find.bySemanticsLabel('$label, 3'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('large text can grow the body and target beyond 48dp', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 1280),
              textScaler: TextScaler.linear(4),
            ),
            child: Center(
              child: AppFilterChip(label: 'I', selected: false, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppFilterChip)).height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });
}
