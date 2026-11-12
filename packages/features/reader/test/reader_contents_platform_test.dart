import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show DefaultTabController, TabBar;
import 'package:reader/src/reader_contents_tab_bar.dart';
import 'package:reader/src/reader_contents_tabs.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  setUpAll(() async {
    final font = await rootBundle.load(
      'packages/component_library/fonts/Geist-Variable.ttf',
    );
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });

  for (final width in [390.0, 440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Cupertino four-tab Contents stays compact at $width in ${brightness.name}',
        (tester) async {
          await _pumpContents(tester, width: width, brightness: brightness);
          expect(find.byType(CupertinoApp), findsOneWidget);
          expect(find.byType(TabBar), findsNothing);
          final nativeFinder = find.byType(
            CupertinoSlidingSegmentedControl<int>,
          );
          expect(nativeFinder, findsOneWidget);
          final native = tester.widget<CupertinoSlidingSegmentedControl<int>>(
            nativeFinder,
          );
          expect(native.proportionalWidth, isTrue);
          expect(
            tester.getSize(find.byType(ReaderContentsTabBar)).height,
            lessThanOrEqualTo(70),
          );
          final context = tester.element(find.byType(ReaderContentsTabBar));
          final choices = tester.widget<AppChoiceControl<int>>(
            find.byType(AppChoiceControl<int>),
          );
          expect(choices.proportionalWidth, isTrue);
          for (final option in choices.options) {
            expect(option.labelStyle, context.text.labelSmall);
          }
          final bounds = tester.getRect(nativeFinder);
          for (final child in native.children.values) {
            final target = tester.getSize(find.byWidget(child));
            expect(target.width, greaterThanOrEqualTo(48));
            expect(target.height, greaterThanOrEqualTo(48));
          }
          _expectReadableLabels(tester, bounds: bounds, singleLine: true);

          await tester.tap(find.text(context.l10n.readerHighlights));
          await tester.pumpAndSettle();
          final controller = DefaultTabController.of(context);
          expect(controller.index, 3);
          expect(
            tester
                .widget<CupertinoSlidingSegmentedControl<int>>(nativeFinder)
                .groupValue,
            3,
          );
          controller.animateTo(1);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<AppChoiceControl<int>>(
                  find.byType(AppChoiceControl<int>),
                )
                .selected,
            1,
          );
          expect(
            tester
                .widget<CupertinoSlidingSegmentedControl<int>>(nativeFinder)
                .groupValue,
            1,
          );
          _expectReadableLabels(tester, bounds: bounds, singleLine: true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Cupertino four-tab iPad sidebar stays compact across rotation in ${brightness.name}',
      (tester) async {
        const portrait = Size(1024, 1366);
        tester.view
          ..physicalSize = portrait
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          PlatformTestApp(
            platform: TargetPlatform.iOS,
            brightness: brightness,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: const _InlineContentsHarness(),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ReaderContentsTabBar));
        final controller = DefaultTabController.of(context);
        final sheetState = tester.state(find.byType(AppInlineSheet));
        final nativeFinder = find.byType(
          CupertinoSlidingSegmentedControl<int>,
        );
        var selectedIndex = 0;
        for (final window in [portrait, const Size(1366, 1024)]) {
          tester.view.physicalSize = window;
          await tester.pumpAndSettle();
          expect(find.byType(CupertinoApp), findsOneWidget);
          expect(find.byType(TabBar), findsNothing);
          expect(tester.state(find.byType(AppInlineSheet)), same(sheetState));
          expect(DefaultTabController.of(context), same(controller));
          expect(controller.index, selectedIndex);
          expect(MediaQuery.sizeOf(context), window);
          expect(nativeFinder, findsOneWidget);
          expect(
            tester.getSize(find.byType(ReaderContentsTabBar)).width,
            AppSizes.sidePanelWidth,
          );
          expect(
            tester.getSize(find.byType(ReaderContentsTabBar)).height,
            lessThanOrEqualTo(70),
          );
          final native = tester.widget<CupertinoSlidingSegmentedControl<int>>(
            nativeFinder,
          );
          expect(native.proportionalWidth, isTrue);
          expect(native.groupValue, controller.index);
          final choices = tester.widget<AppChoiceControl<int>>(
            find.byType(AppChoiceControl<int>),
          );
          expect(choices.selected, controller.index);
          for (final child in native.children.values) {
            final target = tester.getSize(find.byWidget(child));
            expect(target.width, greaterThanOrEqualTo(48));
            expect(target.height, greaterThanOrEqualTo(48));
          }
          expect(context.text.bodyMedium.fontSize, 15);
          _expectReadableLabels(
            tester,
            bounds: tester.getRect(nativeFinder),
            singleLine: true,
            fontSize: context.text.bodyMedium.fontSize,
          );
          await tester.tap(find.text(context.l10n.readerHighlights));
          await tester.pumpAndSettle();
          expect(controller.index, 3);
          expect(
            tester
                .widget<CupertinoSlidingSegmentedControl<int>>(nativeFinder)
                .groupValue,
            3,
          );
          controller.animateTo(1);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<AppChoiceControl<int>>(
                  find.byType(AppChoiceControl<int>),
                )
                .selected,
            1,
          );
          expect(
            tester
                .widget<CupertinoSlidingSegmentedControl<int>>(nativeFinder)
                .groupValue,
            1,
          );
          selectedIndex = 1;
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  for (final (name, locale, scale) in [
    ('narrow phone', const Locale('en'), 1.0),
    ('large German labels', const Locale('de'), 2.0),
    ('large RTL labels', const Locale('ar'), 2.0),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Cupertino Contents keeps $name reachable in ${brightness.name}',
        (tester) async {
          await _pumpContents(
            tester,
            width: 320,
            locale: locale,
            scale: scale,
            brightness: brightness,
          );
          expect(find.byType(CupertinoApp), findsOneWidget);
          expect(find.byType(TabBar), findsNothing);
          expect(
            find.byType(CupertinoSlidingSegmentedControl<int>),
            findsNothing,
          );
          final buttons = find.descendant(
            of: find.byType(AppChoiceControl<int>),
            matching: find.byType(AppButton),
          );
          expect(buttons, findsNWidgets(4));
          for (final button in buttons.evaluate()) {
            final size = tester.getSize(find.byWidget(button.widget));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          for (final scrollable in tester.widgetList<Scrollable>(
            find.byType(Scrollable),
          )) {
            expect(
              axisDirectionToAxis(scrollable.axisDirection),
              Axis.vertical,
            );
          }
          final context = tester.element(find.byType(ReaderContentsTabBar));
          expect(
            Directionality.of(context),
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          _expectReadableLabels(
            tester,
            bounds: tester.getRect(find.byType(ReaderContentsTabBar)),
          );
          final last = find.text(context.l10n.readerHighlights);
          await tester.ensureVisible(last);
          await tester.pumpAndSettle();
          expect(last.hitTestable(), findsOneWidget);
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(DefaultTabController.of(context).index, 3);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _pumpContents(
  WidgetTester tester, {
  required double width,
  required Brightness brightness,
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  tester.view
    ..physicalSize = Size(width, 568)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PlatformTestApp(
      platform: TargetPlatform.iOS,
      brightness: brightness,
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      textScale: scale,
      home: const DefaultTabController(
        length: 4,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: ReaderContentsTabBar(tabs: ReaderContentsTab.values),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectReadableLabels(
  WidgetTester tester, {
  required Rect bounds,
  bool singleLine = false,
  double? fontSize,
}) {
  final labels = find.descendant(
    of: find.byType(AppChoiceControl<int>),
    matching: find.byType(Text),
  );
  expect(labels, findsNWidgets(4));
  for (final element in labels.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final label = paragraph.text.toPlainText();
    if (fontSize != null) {
      expect(paragraph.text.style?.fontSize, fontSize, reason: label);
    }
    expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: label.length),
    );
    final origin = paragraph.localToGlobal(Offset.zero);
    expect(boxes, isNotEmpty, reason: label);
    if (singleLine) {
      expect(boxes.map((box) => box.top.round()).toSet(), hasLength(1));
    }
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(-.01), reason: label);
      expect(
        box.right,
        lessThanOrEqualTo(paragraph.size.width + .01),
        reason: label,
      );
      expect(
        origin.dy + box.top,
        greaterThanOrEqualTo(bounds.top - .01),
        reason: label,
      );
      expect(
        origin.dy + box.bottom,
        lessThanOrEqualTo(bounds.bottom + .01),
        reason: label,
      );
    }
    final rect = tester.getRect(find.byWidget(element.widget));
    expect(rect.left, greaterThanOrEqualTo(bounds.left - .01), reason: label);
    expect(rect.right, lessThanOrEqualTo(bounds.right + .01), reason: label);
  }
}

class _InlineContentsHarness extends StatelessWidget {
  const _InlineContentsHarness();

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Stack(
      fit: StackFit.expand,
      children: [
        AppInlineSheet(
          visible: true,
          onClose: () {},
          semanticsLabel: context.l10n.readerContents,
          header: const SizedBox.shrink(),
          body: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [ReaderContentsTabBar(tabs: ReaderContentsTab.values)],
          ),
        ),
      ],
    ),
  );
}
