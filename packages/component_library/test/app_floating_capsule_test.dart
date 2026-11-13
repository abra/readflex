import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

import '../test_support/platform_test_app.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.iOS,
    Brightness brightness = Brightness.light,
    bool highContrast = false,
    bool accessibleNavigation = false,
    double height = 56,
    Widget child = const SizedBox(width: 120),
  }) async {
    await tester.pumpWidget(
      PlatformTestApp(
        platform: platform,
        brightness: brightness,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
              accessibleNavigation: accessibleNavigation,
            ),
            child: Center(
              child: AppFloatingCapsule(
                key: const ValueKey('capsule'),
                height: height,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('Cupertino bounds its blur and keeps readable captions '
        '$brightness', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, brightness: brightness);
      final context = tester.element(find.byType(AppFloatingCapsule));
      final appearance = AppSurfaceAppearance.resolve(
        context,
        AppSurfaceRole.floatingToolbar,
      );
      expect(appearance.color.a, closeTo(kAppFloatingCapsuleOpacity, .001));
      expect(appearance.shape, isA<StadiumBorder>());
      expect(appearance.shape.side.width, 1 / 3);
      expect(appearance.shadows, hasLength(1));
      expect(appearance.shadows.single.offset, const Offset(0, 2));
      expect(appearance.shadows.single.blurRadius, 7);
      expect(appearance.blurSigma, 18);
      final blur = find.byType(BackdropFilter);
      expect(blur, findsOneWidget);
      expect(
        find.ancestor(of: blur, matching: find.byType(ClipPath)),
        findsOneWidget,
      );
      expect(
        tester.getSize(blur),
        tester.getSize(find.byType(AppFloatingCapsule)),
      );

      for (final backdrop in [
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
        const Color(0xFF7A1F2B),
      ]) {
        final plate = Color.alphaBlend(appearance.color, backdrop);
        final ink = Color.alphaBlend(context.colors.onSurfaceVariant, plate);
        final first = ink.computeLuminance() + .05;
        final second = plate.computeLuminance() + .05;
        expect(
          first > second ? first / second : second / first,
          greaterThanOrEqualTo(4.5),
          reason: 'small captions over $backdrop',
        );
      }
    });
  }

  for (final highContrast in [false, true]) {
    testWidgets('Cupertino accessibility preferences use an opaque fill '
        'highContrast=$highContrast', (tester) async {
      await pump(
        tester,
        highContrast: highContrast,
        accessibleNavigation: !highContrast,
      );
      final appearance = AppSurfaceAppearance.resolve(
        tester.element(find.byType(AppFloatingCapsule)),
        AppSurfaceRole.floatingToolbar,
      );
      expect(appearance.color.a, 1);
      expect(appearance.blurSigma, 0);
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isFalse,
      );
    });
  }

  testWidgets('accessibility changes preserve the focused capsule field', (
    tester,
  ) async {
    var highContrast = false;
    var accessibleNavigation = false;
    var mounts = 0;
    late StateSetter update;
    await tester.pumpWidget(
      PlatformTestApp(
        platform: TargetPlatform.iOS,
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                highContrast: highContrast,
                accessibleNavigation: accessibleNavigation,
              ),
              child: Center(
                child: AppFloatingCapsule(
                  height: 56,
                  child: _CapsuleField(onMount: () => mounts++),
                ),
              ),
            );
          },
        ),
      ),
    );
    final field = find.byType(_CapsuleField);
    final state = tester.state<_CapsuleFieldState>(field);
    await tester.showKeyboard(find.byType(EditableText));
    await tester.enterText(
      find.byType(EditableText),
      'A retained search query',
    );
    state.controller.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 10,
    );
    final value = state.controller.value;
    for (final preferences in [
      (true, false),
      (false, false),
      (false, true),
      (false, false),
    ]) {
      update(() {
        highContrast = preferences.$1;
        accessibleNavigation = preferences.$2;
      });
      await tester.pumpAndSettle();
      expect(tester.state<_CapsuleFieldState>(field), same(state));
      expect(mounts, 1);
      expect(state.controller.value, value);
      expect(state.focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        !(highContrast || accessibleNavigation),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Material uses semantic fill and native elevation', (
    tester,
  ) async {
    await pump(tester, platform: TargetPlatform.android);
    final context = tester.element(find.byType(AppFloatingCapsule));
    final surface = tester.widget<material.Material>(
      find.descendant(
        of: find.byType(AppFloatingCapsule),
        matching: find.byType(material.Material),
      ),
    );
    expect(surface.color, context.colors.surfaceContainerLow);
    expect(surface.elevation, 2);
    expect(surface.shape, isA<StadiumBorder>());
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppFloatingCapsule),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is ShapeDecoration &&
              ((widget.decoration as ShapeDecoration).shadows?.isNotEmpty ??
                  false),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('takes the given height, a matching stadium radius and hugs '
      'its child', (tester) async {
    await pump(tester, height: 60);
    final size = tester.getSize(find.byKey(const ValueKey('capsule')));
    expect(size, const Size(120, 60));
  });

  testWidgets('keeps the controls interactive and inked by themselves', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      child: AppPlainIconButton(
        icon: AppIcons.add,
        tooltip: 'Add',
        onPressed: () => taps++,
      ),
    );
    await tester.tap(find.byTooltip('Add'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

class _CapsuleField extends StatefulWidget {
  const _CapsuleField({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_CapsuleField> createState() => _CapsuleFieldState();
}

class _CapsuleFieldState extends State<_CapsuleField> {
  final controller = TextEditingController();
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: AppTextField(
      controller: controller,
      focusNode: focus,
      borderless: true,
      filled: false,
    ),
  );
}
