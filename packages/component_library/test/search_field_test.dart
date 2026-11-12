import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
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
            await tester.showKeyboard(find.byType(EditableText));
            await tester.pumpAndSettle();
            final fieldRect = tester.getRect(find.byType(AppTextField));
            final editableRect = tester.getRect(find.byType(EditableText));
            final prefixRect = tester.getRect(find.byIcon(AppIcons.search));
            final button = find.byTooltip('Clear query');
            expect(button, findsOneWidget);
            expect(tester.getSemantics(button).tooltip, 'Clear query');
            expect(tester.getSize(button), const Size.square(48));
            final ink = platform == TargetPlatform.android
                ? tester.widget<InkWell>(
                    find.descendant(
                      of: find.byType(AppPlainIconButton),
                      matching: find.byType(InkWell),
                    ),
                  )
                : null;
            if (ink != null) {
              expect(ink.customBorder, isA<CircleBorder>());
              expect(
                ink.overlayColor!.resolve({WidgetState.pressed})!.a,
                greaterThan(0),
              );
            }
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );

            final gesture = await tester.startGesture(tester.getCenter(button));
            await tester.pump(const Duration(milliseconds: 100));
            if (platform == TargetPlatform.iOS) {
              // Cupertino starts its fade once the tap recognizer accepts.
              await tester.pump(const Duration(milliseconds: 100));
            }
            if (ink != null) {
              expect(
                ink.statesController!.value,
                contains(WidgetState.pressed),
              );
            } else {
              final fade = tester.widget<FadeTransition>(
                find.descendant(
                  of: find.byType(AppPlainIconButton),
                  matching: find.byType(FadeTransition),
                ),
              );
              expect(fade.opacity.value, lessThan(1));
            }
            expect(changes, isEmpty);
            expect(tester.getRect(find.byType(AppTextField)), fieldRect);
            await gesture.up();
            await tester.pumpAndSettle();
            expect(controller.text, isEmpty);
            expect(changes, ['']);
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
            expect(find.byTooltip('Clear query'), findsNothing);
            expect(tester.getRect(find.byType(AppTextField)), fieldRect);
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
      tester.widget<EditableText>(find.byType(EditableText)).textInputAction,
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
      tester.widget<EditableText>(find.byType(EditableText)).textInputAction,
      isNull,
    );
  });
}
