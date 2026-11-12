import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
// The compatibility bridge must keep legacy consumers synchronized too.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as modern;
import 'package:readflex/app/readflex_platform_app.dart';

const _probeKey = ValueKey('animated-theme-probe');

void main() {
  for (final (initial, target) in const [
    (Brightness.light, Brightness.dark),
    (Brightness.dark, Brightness.light),
  ]) {
    testWidgets(
      'Android theme interpolates $initial to $target without replacing the editor',
      (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final brightness = ValueNotifier(initial);
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(brightness.dispose);
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          ValueListenableBuilder<Brightness>(
            valueListenable: brightness,
            builder: (_, value, _) => ReadflexPlatformApp(
              brightness: value,
              home: _EditingProbe(
                key: _probeKey,
                controller: controller,
                focus: focus,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'Retained search');
        await tester.pump();
        final editor = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final startColor = AppTheme.forPlatform(
          TargetPlatform.android,
          initial,
        ).colorScheme.surface;
        final targetColor = AppTheme.forPlatform(
          TargetPlatform.android,
          target,
        ).colorScheme.surface;
        expect(_colorsOf(tester).semantic, startColor);
        brightness.value = target;
        await tester.pump();
        final start = _colorsOf(tester);
        _expectSynchronized(start);
        expect(start.semantic, startColor);
        _expectEditorRetained(tester, editor, controller, focus);

        final duration = tester
            .widget<modern.MaterialApp>(
              find.byType(modern.MaterialApp),
            )
            .themeAnimationDuration;
        await tester.pump(Duration(microseconds: duration.inMicroseconds ~/ 2));
        final midpoint = _colorsOf(tester);
        _expectSynchronized(midpoint);
        expect(midpoint.semantic, isNot(startColor));
        expect(midpoint.semantic, isNot(targetColor));
        _expectEditorRetained(tester, editor, controller, focus);

        await tester.pump(duration);
        final end = _colorsOf(tester);
        _expectSynchronized(end);
        expect(end.semantic, targetColor);
        _expectEditorRetained(tester, editor, controller, focus);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('standalone platform theme honors its explicit brightness', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      modern.MaterialApp(
        theme: AppTheme.forPlatform(TargetPlatform.android, Brightness.light),
        home: const AppPlatformTheme(
          platform: TargetPlatform.android,
          brightness: Brightness.dark,
          child: AppScaffold(body: Text('Standalone theme')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Standalone theme'));
    final expected = AppTheme.forPlatform(
      TargetPlatform.android,
      Brightness.dark,
    );
    expect(context.colors.surface, expected.colorScheme.surface);
    expect(
      modern.Theme.of(context).colorScheme.surface,
      expected.colorScheme.surface,
    );
    expect(context.colors.brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}

class _EditingProbe extends StatelessWidget {
  const _EditingProbe({
    required this.controller,
    required this.focus,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) => AppScaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: AppTextField(controller: controller, focusNode: focus),
      ),
    ),
  );
}

({Color semantic, Color modern, Color legacy}) _colorsOf(WidgetTester tester) {
  final context = tester.element(find.byKey(_probeKey));
  return (
    semantic: context.colors.surface,
    modern: modern.Theme.of(context).colorScheme.surface,
    legacy: legacy.Theme.of(context).colorScheme.surface,
  );
}

void _expectSynchronized(
  ({Color semantic, Color modern, Color legacy}) colors,
) {
  expect(colors.semantic, colors.modern);
  expect(colors.legacy, colors.modern);
}

void _expectEditorRetained(
  WidgetTester tester,
  EditableTextState original,
  TextEditingController controller,
  FocusNode focus,
) {
  expect(
    tester.state<EditableTextState>(find.byType(EditableText)),
    same(original),
  );
  expect(controller.text, 'Retained search');
  expect(focus.hasFocus, isTrue);
}
