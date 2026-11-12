import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:readflex/app/readflex_platform_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('platform app uses native page and controls on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        ReadflexPlatformApp(
          home: AppScaffold(
            appBar: const AppNavigationBar(title: Text('Library')),
            body: AppButton(onPressed: () {}, child: const Text('Import')),
          ),
        ),
      );
      expect(
        find.byType(
          platform == TargetPlatform.iOS
              ? cupertino.CupertinoApp
              : material.MaterialApp,
        ),
        findsOneWidget,
      );
      expect(
        find.byType(
          platform == TargetPlatform.iOS
              ? cupertino.CupertinoPageScaffold
              : material.Scaffold,
        ),
        findsOneWidget,
      );
      expect(
        find.byType(
          platform == TargetPlatform.iOS
              ? cupertino.CupertinoButton
              : material.FilledButton,
        ),
        findsWidgets,
      );
      final context = tester.element(find.text('Import'));
      expect(context.isCupertino, platform == TargetPlatform.iOS);
      expect(context.appTheme.platform, platform);
      expect(
        context.colors.primary,
        AppTheme.forPlatform(platform, Brightness.light).colorScheme.primary,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Cupertino scaffold respects a custom preferred header height',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ReadflexPlatformApp(
          home: AppScaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: SizedBox(height: 64),
            ),
            body: SizedBox.expand(key: ValueKey('custom-header-body')),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('custom-header-body'))).dy,
        88,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cupertino chrome keeps editing state across theme and keyboard changes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final controller = TextEditingController();
      final focus = FocusNode();
      final brightness = ValueNotifier(Brightness.light);
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(brightness.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<Brightness>(
          valueListenable: brightness,
          builder: (_, value, _) => ReadflexPlatformApp(
            brightness: value,
            home: AppScaffold(
              body: AppTextField(
                controller: controller,
                focusNode: focus,
                hintText: 'Search',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'The long book title');
      final original = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      brightness.value = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        identical(
          original,
          tester.state<EditableTextState>(find.byType(EditableText)),
        ),
        isTrue,
      );
      expect(controller.text, 'The long book title');
      expect(focus.hasFocus, isTrue);
      final context = tester.element(find.byType(AppTextField));
      expect(context.appTheme.colors.brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Cupertino floating toolbar follows keyboard without consuming safe area twice',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        const ReadflexPlatformApp(
          home: AppScaffold(
            body: SizedBox.expand(),
            floatingActionButton: SizedBox(
              key: ValueKey('dock'),
              width: 220,
              height: 56,
            ),
            floatingActionButtonLocation:
                AppFloatingActionButtonLocation.centerFloat,
          ),
        ),
      );
      expect(tester.getBottomRight(find.byKey(const ValueKey('dock'))).dy, 794);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(tester.getBottomRight(find.byKey(const ValueKey('dock'))).dy, 528);
      expect(find.byType(material.Scaffold), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
