import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _textInputActionTests();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'search clear feedback and focus: $platform / $brightness / $direction',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = TextEditingController(text: 'query');
            final focus = FocusNode();
            addTearDown(controller.dispose);
            addTearDown(focus.dispose);
            final changes = <String>[];
            final theme = brightness == Brightness.light
                ? AppTheme.light()
                : AppTheme.dark();
            await tester.pumpWidget(
              MaterialApp(
                theme: theme.copyWith(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: SearchField(
                    hintText: 'Search',
                    clearButtonSemanticsLabel: 'Clear query',
                    controller: controller,
                    focusNode: focus,
                    onChanged: changes.add,
                  ),
                ),
              ),
            );
            await tester.showKeyboard(find.byType(TextField));
            await tester.pumpAndSettle();
            final fieldRect = tester.getRect(find.byType(TextField));
            final editableRect = tester.getRect(find.byType(EditableText));
            final prefixRect = tester.getRect(find.byIcon(AppIcons.search));
            final button = find.byTooltip('Clear query');
            expect(button, findsOneWidget);
            expect(tester.getSemantics(button).tooltip, 'Clear query');
            expect(tester.getSize(button), const Size.square(48));
            final ink = tester.widget<InkWell>(
              find.descendant(
                of: find.byType(AppPlainIconButton),
                matching: find.byType(InkWell),
              ),
            );
            expect(ink.customBorder, isA<CircleBorder>());
            expect(
              ink.overlayColor!.resolve({WidgetState.pressed})!.a,
              greaterThan(0),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );

            final gesture = await tester.startGesture(tester.getCenter(button));
            await tester.pump(const Duration(milliseconds: 100));
            expect(ink.statesController!.value, contains(WidgetState.pressed));
            expect(changes, isEmpty);
            expect(tester.getRect(find.byType(TextField)), fieldRect);
            await gesture.up();
            await tester.pumpAndSettle();
            expect(controller.text, isEmpty);
            expect(changes, ['']);
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
            expect(find.byTooltip('Clear query'), findsNothing);
            expect(tester.getRect(find.byType(TextField)), fieldRect);
            expect(tester.getRect(find.byType(EditableText)), editableRect);
            expect(tester.getRect(find.byIcon(AppIcons.search)), prefixRect);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

void _textInputActionTests() {
  testWidgets('textInputAction passes through to the text field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SearchField(
            hintText: 'Search',
            textInputAction: TextInputAction.search,
          ),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).textInputAction,
      TextInputAction.search,
    );
  });

  testWidgets('textInputAction defaults to the platform keyboard action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SearchField(hintText: 'Search')),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).textInputAction,
      isNull,
    );
  });
}
