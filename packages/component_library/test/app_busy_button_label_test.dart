import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool busy,
    String label = 'Save',
    int? maxLines = 2,
    double? width,
    double textScale = 1,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: FilledButton(
                onPressed: busy ? null : () {},
                child: AppBusyButtonLabel(
                  label,
                  busy: busy,
                  maxLines: maxLines,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('busy keeps the button size and announces the label', (
    tester,
  ) async {
    await pump(tester, busy: false);
    final idle = tester.getSize(find.byType(FilledButton));
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(ButtonLoadingIndicator), findsNothing);

    await pump(tester, busy: true);
    expect(tester.getSize(find.byType(FilledButton)), idle);
    expect(find.byType(ButtonLoadingIndicator), findsOneWidget);
    final hidden = tester.widget<Visibility>(find.byType(Visibility));
    expect(hidden.visible, isFalse);
    expect(hidden.maintainSize, isTrue);
    final live = tester.getSemantics(find.byType(ButtonLoadingIndicator));
    expect(live.label, 'Save');
    expect(live.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('unbounded large labels wrap fully and keep busy geometry', (
    tester,
  ) async {
    const label = 'Zu ausgewählten Sammlungen hinzufügen';
    tester.view
      ..physicalSize = const Size(320, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      busy: false,
      label: label,
      maxLines: null,
      width: 160,
      textScale: 2,
    );
    final idle = tester.getSize(find.byType(FilledButton));
    final text = tester.widget<Text>(find.text(label));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(label), matching: find.byType(RichText)),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, TextOverflow.visible);
    expect(paragraph.didExceedMaxLines, isFalse);
    final glyphs = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: label.length),
    );
    expect(glyphs.map((box) => box.top).toSet().length, greaterThan(2));
    final button = tester.getRect(find.byType(FilledButton));
    final paragraphOrigin = paragraph.localToGlobal(Offset.zero);
    for (final box in glyphs) {
      expect(paragraphOrigin.dy + box.bottom, lessThanOrEqualTo(button.bottom));
    }

    await pump(
      tester,
      busy: true,
      label: label,
      maxLines: null,
      width: 160,
      textScale: 2,
    );
    expect(tester.getSize(find.byType(FilledButton)), idle);
    final live = tester.getSemantics(find.byType(ButtonLoadingIndicator));
    expect(live.label, label);
    expect(live.flagsCollection.isLiveRegion, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared by AppSheetActions and ErrorState', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              AppSheetActions(
                primaryLabel: 'Save',
                onPrimary: () {},
                secondaryLabel: 'Cancel',
                onSecondary: () {},
                busy: true,
              ),
              ErrorState(
                message: 'Failed',
                retryLabel: 'Retry',
                onRetry: () {},
                busy: true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(AppBusyButtonLabel), findsNWidgets(2));
    expect(find.byType(ButtonLoadingIndicator), findsNWidgets(2));
  });
}
