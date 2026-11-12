import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'action and icon use platform controls with named targets: $platform',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var commands = 0;
          await _pump(
            tester,
            platform,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  key: const ValueKey('action'),
                  onPressed: () => commands++,
                  child: const AppButtonLabel('Save'),
                ),
                AppPlainIconButton(
                  key: const ValueKey('icon'),
                  tooltip: 'Close',
                  icon: AppIcons.close,
                  onPressed: () => commands++,
                ),
              ],
            ),
          );
          expect(
            find.byType(cupertino.CupertinoButton),
            platform == TargetPlatform.iOS ? findsNWidgets(2) : findsNothing,
          );
          expect(
            find.byType(material.FilledButton),
            platform == TargetPlatform.android ? findsOneWidget : findsNothing,
          );
          for (final key in ['action', 'icon']) {
            final target = find.byKey(ValueKey(key));
            final size = tester.getSize(target);
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
            await tester.tap(target);
          }
          expect(commands, 2);
          expect(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'long RTL action and busy state retain readable geometry: $platform',
      (tester) async {
        const label = 'إضافة جميع العناصر المحددة إلى المجموعة';
        Future<void> show(bool busy) => _pump(
          tester,
          platform,
          SizedBox(
            width: 180,
            child: AppButton(
              onPressed: busy ? null : () {},
              child: AppBusyButtonLabel(label, busy: busy, maxLines: null),
            ),
          ),
          textScale: 2,
          direction: TextDirection.rtl,
        );
        await show(false);
        final before = tester.getRect(find.byType(AppButton));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, lessThanOrEqualTo(before.height));
        await show(true);
        expect(tester.getRect(find.byType(AppButton)), before);
        expect(find.byType(AppProgressIndicator), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byType(ButtonLoadingIndicator))
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'progress exposes platform-independent accessible roles and values: $platform',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            platform,
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppProgressIndicator(
                  value: .25,
                  semanticsLabel: 'Import progress',
                ),
                AppLinearProgressIndicator(
                  value: .75,
                  semanticsLabel: 'Reading progress',
                ),
                AppProgressIndicator(semanticsLabel: 'Loading'),
              ],
            ),
          );
          for (final (label, value) in [
            ('Import progress', '25'),
            ('Reading progress', '75'),
          ]) {
            final data = tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData();
            expect(data.role, SemanticsRole.progressBar);
            expect(data.value, value);
            expect(data.minValue, '0');
            expect(data.maxValue, '100');
          }
          expect(
            tester
                .getSemantics(find.bySemanticsLabel('Loading'))
                .getSemanticsData()
                .role,
            SemanticsRole.loadingSpinner,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'standalone progress preserves platform defaults and button size: $platform',
      (tester) async {
        await _pump(
          tester,
          platform,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppProgressIndicator(key: ValueKey('standalone')),
              const ButtonLoadingIndicator(),
              if (platform == TargetPlatform.android)
                const material.CircularProgressIndicator(
                  key: ValueKey('platformDefault'),
                ),
            ],
          ),
        );
        expect(
          tester.getSize(find.byType(ButtonLoadingIndicator)),
          const Size.square(20),
        );
        final standalone = tester.getSize(
          find.byKey(const ValueKey('standalone')),
        );
        expect(
          standalone,
          platform == TargetPlatform.android
              ? tester.getSize(find.byKey(const ValueKey('platformDefault')))
              : const Size.square(20),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'custom search hint remains named at 200% RTL: $platform',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            platform,
            const SearchField(
              hintText: 'Search saved chapters',
              compactHintText: 'Search',
            ),
            textScale: 2,
            direction: TextDirection.rtl,
            width: 240,
          );
          expect(
            find.bySemanticsLabel('Search saved chapters'),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel('Search'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'text editing keeps focus and connection when border error changes: $platform',
      (tester) async {
        final controller = TextEditingController(text: 'draft');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        var changed = '';
        var submitted = '';
        Future<void> show(bool hasError) => _pump(
          tester,
          platform,
          AppTextField(
            controller: controller,
            focusNode: focus,
            hintText: 'Collection name',
            hasError: hasError,
            textInputAction: TextInputAction.done,
            onChanged: (value) => changed = value,
            onSubmitted: (value) => submitted = value,
          ),
        );
        await show(false);
        expect(
          find.byType(cupertino.CupertinoTextField),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(material.TextField),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        if (platform == TargetPlatform.iOS) {
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .style
                .fontSize,
            17,
          );
        }
        await tester.showKeyboard(find.byType(EditableText));
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final rect = tester.getRect(find.byType(AppTextField));
        await show(true);
        expect(
          identical(
            tester.state<EditableTextState>(find.byType(EditableText)),
            editable,
          ),
          isTrue,
        );
        expect(tester.getRect(find.byType(AppTextField)), rect);
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.enterText(find.byType(EditableText), 'Updated');
        expect(changed, 'Updated');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(submitted, 'Updated');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('choice supports selection and disables commands: $platform', (
      tester,
    ) async {
      var selected = 0;
      var enabled = true;
      var calls = 0;
      late StateSetter update;
      await _pump(
        tester,
        platform,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return AppChoiceControl<int>(
              selected: selected,
              options: const [
                AppChoiceOption(value: 0, label: 'Light'),
                AppChoiceOption(value: 1, label: 'Dark'),
              ],
              onChanged: enabled
                  ? (value) => setState(() {
                      selected = value;
                      calls++;
                    })
                  : null,
            );
          },
        ),
      );
      expect(
        find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(calls, 1);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'large choice labels use reachable wrapping buttons: $platform',
      (tester) async {
        var selected = 0;
        await _pump(
          tester,
          platform,
          StatefulBuilder(
            builder: (context, setState) => AppChoiceControl<int>(
              selected: selected,
              options: const [
                AppChoiceOption(
                  value: 0,
                  label: 'Systemeinstellungen übernehmen',
                ),
                AppChoiceOption(value: 1, label: 'Dunkles Erscheinungsbild'),
              ],
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
          textScale: 2,
          width: 240,
        );
        expect(
          find.byType(cupertino.CupertinoSlidingSegmentedControl<int>),
          findsNothing,
        );
        await tester.tap(find.text('Dunkles Erscheinungsbild'));
        await tester.pumpAndSettle();
        expect(selected, 1);
        for (final text in find.byType(Text).evaluate()) {
          final rich = find.descendant(
            of: find.byWidget(text.widget),
            matching: find.byType(RichText),
          );
          if (rich.evaluate().isNotEmpty) {
            expect(
              tester.renderObject<RenderParagraph>(rich).didExceedMaxLines,
              isFalse,
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'switch, slider and checkbox preserve input contracts: $platform',
      (tester) async {
        var checked = false;
        var switched = false;
        var value = .25;
        await _pump(
          tester,
          platform,
          StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSwitch(
                  value: switched,
                  onChanged: (next) => setState(() => switched = next),
                ),
                AppCheckbox(
                  value: checked,
                  onChanged: (next) => setState(() => checked = next!),
                ),
                AppSlider(
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ],
            ),
          ),
        );
        for (final type in [AppSwitch, AppCheckbox, AppSlider]) {
          expect(
            tester.getSize(find.byType(type)).height,
            greaterThanOrEqualTo(48),
          );
        }
        await tester.tap(find.byType(AppSwitch));
        await tester.pumpAndSettle();
        expect(switched, isTrue);
        await tester.tap(find.byType(AppCheckbox));
        await tester.pumpAndSettle();
        expect(checked, isTrue);
        final slider = tester.getRect(find.byType(AppSlider));
        await tester.dragFrom(
          Offset(slider.left + slider.width * .25, slider.center.dy),
          const Offset(60, 0),
        );
        await tester.pumpAndSettle();
        expect(value, greaterThan(.25));
        expect(
          find.byType(cupertino.CupertinoSwitch),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(cupertino.CupertinoSlider),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'one Cupertino choice keeps native presentation',
    (tester) async {
      var changes = 0;
      await _pump(
        tester,
        TargetPlatform.iOS,
        AppChoiceControl<int>(
          selected: 1,
          options: const [AppChoiceOption(value: 1, label: 'Book')],
          onChanged: (_) => changes++,
        ),
      );
      expect(find.byType(material.SegmentedButton<int>), findsNothing);
      expect(find.byType(cupertino.CupertinoButton), findsOneWidget);
      await tester.tap(find.text('Book'));
      expect(changes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android icon action preserves native spacing with large text',
    (tester) async {
      const style = TextStyle(fontSize: 17);
      await _pump(
        tester,
        TargetPlatform.android,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton.icon(
              key: const ValueKey('adaptiveIconButton'),
              onPressed: () {},
              textStyle: style,
              icon: const Icon(AppIcons.add, key: ValueKey('adaptiveIcon')),
              label: const Text('Add', key: ValueKey('adaptiveLabel')),
            ),
            material.FilledButton.icon(
              key: const ValueKey('referenceIconButton'),
              onPressed: () {},
              style: material.TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                alignment: Alignment.center,
                textStyle: style,
              ),
              icon: const Icon(AppIcons.add, key: ValueKey('referenceIcon')),
              label: const Text('Add', key: ValueKey('referenceLabel')),
            ),
          ],
        ),
        textScale: 2,
      );
      final adaptiveIcon = tester.getRect(
        find.byKey(const ValueKey('adaptiveIcon')),
      );
      final referenceIcon = tester.getRect(
        find.byKey(const ValueKey('referenceIcon')),
      );
      final adaptiveLabel = tester.getRect(
        find.byKey(const ValueKey('adaptiveLabel')),
      );
      final referenceLabel = tester.getRect(
        find.byKey(const ValueKey('referenceLabel')),
      );
      expect(
        adaptiveLabel.left - adaptiveIcon.right,
        referenceLabel.left - referenceIcon.right,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('adaptiveIconButton'))),
        tester.getSize(find.byKey(const ValueKey('referenceIconButton'))),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cupertino toolbar input respects a bounded 48dp field and keeps editing state',
    (tester) async {
      final controller = TextEditingController(text: 'query');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await _pump(
        tester,
        TargetPlatform.iOS,
        SizedBox(
          height: 48,
          child: AppTextField(
            controller: controller,
            focusNode: focus,
            borderless: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            hintText: 'Search',
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppTextField)).height, 48);
      await tester.showKeyboard(find.byType(EditableText));
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cupertino custom tap area cancels on drag and activates by keyboard',
    (tester) async {
      var commands = 0;
      await _pump(
        tester,
        TargetPlatform.iOS,
        AppSurface(
          child: AppTappable(
            onTap: () => commands++,
            child: const SizedBox(
              width: 200,
              height: 80,
              child: Center(child: Text('Open book')),
            ),
          ),
        ),
      );
      expect(find.byType(material.InkWell), findsNothing);
      final pointer = await tester.startGesture(
        tester.getCenter(find.byType(AppTappable)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        .55,
      );
      await pointer.moveBy(const Offset(80, 0));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(commands, 0);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(commands, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child, {
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  double? width,
}) async {
  tester.view
    ..physicalSize = const Size(320, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final body = AppPlatformTheme(
    platform: platform,
    brightness: Brightness.light,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    platform == TargetPlatform.iOS
        ? cupertino.CupertinoApp(
            localizationsDelegates:
                material.GlobalMaterialLocalizations.delegates,
            home: cupertino.CupertinoPageScaffold(child: body),
          )
        : material.MaterialApp(
            theme: AppTheme.forPlatform(platform, Brightness.light),
            home: material.Scaffold(body: body),
          ),
  );
}
