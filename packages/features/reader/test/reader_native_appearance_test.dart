import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoApp;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp;
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';
import 'package:reader/src/reader_font_sheet.dart';
import 'package:reader/src/reader_layout_presets.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      ('Geist', 'Geist-Variable.ttf'),
      ('Literata', 'Literata-Variable.ttf'),
      ('CupertinoSystemText', 'Geist-Variable.ttf'),
      ('CupertinoSystemDisplay', 'Geist-Variable.ttf'),
    ]) {
      await (FontLoader(family)..addFont(
            rootBundle.load('packages/component_library/fonts/$file'),
          ))
          .load();
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final (locale, size, scale) in [
      (const Locale('en'), const Size(390, 844), 1.0),
      (const Locale('de'), const Size(320, 568), 2.0),
      (const Locale('ar'), const Size(320, 568), 2.0),
    ]) {
      testWidgets('$platform Appearance is reachable at $locale ${scale}x', (
        tester,
      ) async {
        final cubit = await tester.openNativeAppearance(
          platform: platform,
          locale: locale,
          size: size,
          scale: scale,
        );
        expect(
          find.byType(
            platform == TargetPlatform.iOS ? CupertinoApp : MaterialApp,
          ),
          findsOneWidget,
        );
        final l10n = tester.element(find.byType(BottomSheetHeader)).l10n;
        expect(
          find.byKey(const ValueKey('reader-typeface-settings')),
          findsOneWidget,
        );
        for (final (key, count) in [
          ('reader-line-height-control', 3),
          ('reader-margin-control', 3),
          ('reader-text-alignment-control', 2),
          ('reader-page-turn-control', 2),
        ]) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          final labels = find.descendant(
            of: control,
            matching: find.byType(Text),
          );
          expect(labels, findsNWidgets(count));
          if (scale == 1) {
            final firstLine = tester.getCenter(labels.first).dy;
            for (var index = 1; index < count; index++) {
              expect(
                tester.getCenter(labels.at(index)).dy,
                closeTo(firstLine, 1),
              );
            }
          }
          for (final element in labels.evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse);
            final text = paragraph.text.toPlainText();
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            );
            expect(
              boxes.map((box) => box.top.round()).toSet().length,
              lessThanOrEqualTo(text.split(RegExp(r'\s+')).length),
              reason: 'The translated choice must not split a word: $text',
            );
          }
        }
        final vertical = find.text(l10n.readerPageTurnVerticalShort);
        await tester.ensureVisible(vertical);
        await tester.pumpAndSettle();
        await tester.tap(vertical);
        await tester.pumpAndSettle();
        expect(
          cubit.state.effectiveAppearance.pageTurnStyle,
          ReaderPageTurnStyle.vertical,
        );
        final relaxed = find.descendant(
          of: find.byKey(const ValueKey('reader-line-height-control')),
          matching: find.text(l10n.readerLineSpacingRelaxed),
        );
        await tester.ensureVisible(relaxed);
        await tester.pumpAndSettle();
        await tester.tap(relaxed);
        await tester.pumpAndSettle();
        expect(
          cubit.state.effectiveAppearance.lineHeight,
          ReaderLineSpacingPreset.relaxed.lineHeight,
        );
        await tester.tap(find.byIcon(AppIcons.refresh).hitTestable());
        await tester.pumpAndSettle();
        expect(cubit.state.hasOverride, isFalse);
        final font = find.byKey(const ValueKey('reader-font-picker'));
        await tester.ensureVisible(font);
        await tester.pumpAndSettle();
        final originalBounds = tester.getRect(
          find.byType(ActionBottomSheetLayout).hitTestable(),
        );
        await tester.tap(font);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(ActionBottomSheetLayout).hitTestable()),
          originalBounds,
        );
        for (final preset in ReaderFontPreset.values) {
          final option = find.byKey(
            ValueKey('reader-font-option-${preset.id}'),
          );
          expect(tester.getSize(option).height, greaterThanOrEqualTo(96));
          final sample = find.byKey(
            ValueKey('reader-font-sample-${preset.id}'),
          );
          final style = tester.widget<Text>(sample).style!;
          expect(
            style.fontSize,
            tester.element(sample).text.bodyLarge.fontSize,
          );
          expect(style.fontWeight, FontWeight.w400);
          expect(style.height, 1.45);
        }
        final lastFont = ReaderFontPreset.values.last;
        final fontOption = find.byKey(
          ValueKey('reader-font-option-${lastFont.id}'),
        );
        await tester.ensureVisible(fontOption);
        await tester.pumpAndSettle();
        expect(fontOption.hitTestable(), findsOneWidget);
        await tester.tap(fontOption);
        await tester.pumpAndSettle();
        expect(cubit.state.effectiveAppearance.fontId, lastFont.id);
        await tester.tap(find.byTooltip(l10n.commonBack).hitTestable());
        await tester.pumpAndSettle();
        expect(font.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(find.byType(ActionBottomSheetLayout).hitTestable()),
          originalBounds,
        );
        await tester.tap(find.byTooltip(l10n.commonClose).hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheetHeader), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform contextual Font retains its state across resizing', (
      tester,
    ) async {
      final cubit = await tester.openNativeAppearance(
        platform: platform,
        size: const Size(1024, 768),
        showColumns: true,
        scale: 2,
      );
      final header = find.byType(BottomSheetHeader);
      expect(tester.getSize(header).width, 420);
      final settingsViewport = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .hitTestable();
      _expectExpandedViewport(tester, settingsViewport);
      final font = find.byKey(const ValueKey('reader-font-picker'));
      await tester.ensureVisible(font);
      await tester.pumpAndSettle();
      await tester.tap(font);
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('reader-font-option-geist'));
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      final fontSheetState = tester.element(find.byType(ReaderFontSheet));
      final scrollable = find.descendant(
        of: find.byType(ReaderFontSheet),
        matching: find.byType(Scrollable),
      );
      final scroll = tester.state<ScrollableState>(scrollable);
      _expectExpandedViewport(tester, scrollable);
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(ReaderFontSheet)),
        same(fontSheetState),
      );
      expect(tester.state<ScrollableState>(scrollable), same(scroll));
      expect(
        scroll.position.pixels,
        offset.clamp(0, scroll.position.maxScrollExtent),
      );
      expect(cubit.state.effectiveAppearance.fontId, 'geist');
      expect(tester.getSize(header.hitTestable()).width, lessThan(420));
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(ReaderFontSheet)),
        same(fontSheetState),
      );
      expect(tester.getSize(header.hitTestable()).width, 420);
      _expectExpandedViewport(tester, scrollable);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform PDF and DjVu expose only applicable page settings', (
      tester,
    ) async {
      final cubit = await tester.openNativeAppearance(
        platform: platform,
        locale: const Locale('ar'),
        size: const Size(320, 568),
        scale: 2,
        pdf: true,
      );
      expect(find.byType(ReaderFontSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('reader-text-scale-control')),
        findsNothing,
      );
      final l10n = tester.element(find.byType(BottomSheetHeader)).l10n;
      for (final label in [
        l10n.readerPdfMarginsWhole,
        l10n.readerPdfPageColorsOriginal,
      ]) {
        final option = find.text(label);
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
      }
      expect(cubit.state.effectiveAppearance.trimPageMargins, isFalse);
      expect(
        cubit.state.effectiveAppearance.pageColors,
        ReaderPageColors.original,
      );
      await tester.tap(find.byIcon(AppIcons.refresh).hitTestable());
      await tester.pumpAndSettle();
      expect(cubit.state.hasOverride, isFalse);
      expect(cubit.state.effectiveAppearance.trimPageMargins, isTrue);
      expect(
        cubit.state.effectiveAppearance.pageColors,
        ReaderPageColors.theme,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

void _expectExpandedViewport(WidgetTester tester, Finder viewport) {
  final content = tester.getRect(
    find.byType(ActionBottomSheetLayout).hitTestable(),
  );
  expect(tester.getRect(viewport).bottom, closeTo(content.bottom, .01));
  expect(768 - content.bottom, inInclusiveRange(0, AppSpacing.lg));
}

extension on WidgetTester {
  Future<ReaderAppearanceCubit> openNativeAppearance({
    required TargetPlatform platform,
    required Size size,
    Locale locale = const Locale('en'),
    double scale = 1,
    bool pdf = false,
    bool showColumns = false,
  }) async {
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    final cubit = ReaderAppearanceCubit(
      preferencesService: preferences,
      sourceId: 'native-appearance',
    );
    addTearDown(cubit.close);
    await pumpWidget(
      PlatformTestApp(
        platform: platform,
        locale: locale,
        textScale: scale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        home: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => Center(
              child: AppButton(
                onPressed: () => showReaderAppearanceSheet(
                  context,
                  pdfControls: pdf,
                  showColumnControls: showColumns,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tap(find.text('Open'));
    await pumpAndSettle();
    return cubit;
  }
}
