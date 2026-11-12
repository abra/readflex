import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

void main() {
  testWidgets('native page actions open and dismiss a Cupertino menu', (
    tester,
  ) async {
    var commands = 0;
    await tester.pumpWidget(
      _CupertinoControlHost(
        child: Builder(
          builder: (context) => AppScaffold(
            appBar: AppNavigationBar(
              title: const Text('Library'),
              actions: [
                AppPlainIconButton(
                  icon: AppIcons.moreHorizontal,
                  tooltip: 'Open menu',
                  onPressed: () => cupertino.showCupertinoModalPopup<void>(
                    context: context,
                    builder: (context) => cupertino.CupertinoActionSheet(
                      actions: [
                        cupertino.CupertinoActionSheetAction(
                          onPressed: () {
                            commands++;
                            Navigator.pop(context);
                          },
                          child: const Text('Display'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            body: const Center(child: Text('Books')),
          ),
        ),
      ),
    );
    expect(find.byType(material.Material), findsNothing);
    expect(find.byType(material.Scaffold), findsNothing);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.byType(cupertino.CupertinoActionSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Display'));
    await tester.pumpAndSettle();
    expect(commands, 1);
    expect(find.byType(cupertino.CupertinoActionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native slider completes tap and drag without a Material host', (
    tester,
  ) async {
    var value = .5;
    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      _CupertinoControlHost(
        child: AppScaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: StatefulBuilder(
                builder: (context, setState) => AppSlider(
                  value: value,
                  semanticsLabel: 'Reading progress',
                  onChanged: (next) => setState(() => value = next),
                  onChangeStart: (_) => starts++,
                  onChangeEnd: (_) => ends++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(material.Slider), findsNothing);
    final slider = find.byType(cupertino.CupertinoSlider);
    await tester.tap(slider);
    await tester.pumpAndSettle();
    await tester.dragFrom(tester.getCenter(slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(value, greaterThan(.5));
    expect(starts, greaterThan(0));
    expect(ends, starts);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('native input opens its selection menu after a long press', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Read this selected text');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _CupertinoControlHost(
        child: AppScaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AppTextField(controller: controller, focusNode: focus),
            ),
          ),
        ),
      ),
    );
    final editor = find.byType(EditableText);
    await tester.tap(editor);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.longPressAt(tester.getTopLeft(editor) + const Offset(45, 12));
    await tester.pumpAndSettle();
    expect(controller.selection.isCollapsed, isFalse);
    expect(
      find.byType(cupertino.CupertinoAdaptiveTextSelectionToolbar),
      findsOneWidget,
    );
    expect(find.byType(material.Material), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'native tooltip hover uses the Navigator overlay without Material',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        const _CupertinoControlHost(
          child: AppScaffold(
            body: Center(
              child: AppTooltip(
                message: 'Selection color',
                child: SizedBox(width: 48, height: 48),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AppTooltip)));
      await tester.pumpAndSettle();
      expect(find.text('Selection color'), findsOneWidget);
      expect(find.byType(material.Material), findsNothing);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _CupertinoControlHost extends StatelessWidget {
  const _CupertinoControlHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => cupertino.CupertinoApp(
    localizationsDelegates: material.GlobalMaterialLocalizations.delegates,
    home: AppPlatformTheme(
      platform: TargetPlatform.iOS,
      brightness: Brightness.light,
      child: child,
    ),
  );
}
