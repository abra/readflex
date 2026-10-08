import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';
import 'package:reader/src/reader_layout_presets.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Layout checks with the bundled faces: the default test font sets every
/// glyph 1em wide, which says nothing about whether ru/de labels fit.
const _gutter = AppSpacing.xl;
const _compactControls = [
  'reader-text-scale-control',
  'reader-line-height-control',
  'reader-margin-control',
];
const _labeledControls = [
  'reader-text-alignment-control',
  'reader-page-turn-control',
];

void main() {
  setUpAll(() async {
    const fonts = {
      'Geist': 'Geist-Variable.ttf',
      'Literata': 'Literata-Variable.ttf',
      'Noto Sans Symbols': 'NotoSansSymbols-Regular.ttf',
    };
    for (final entry in fonts.entries) {
      await (FontLoader(entry.key)..addFont(
            rootBundle.load('packages/component_library/fonts/${entry.value}'),
          ))
          .load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('setting rows sit on the 24dp gutter at 390dp $locale', (
      tester,
    ) async {
      await tester.openSheet(locale: locale, size: const Size(390, 1100));
      final rtl = locale.languageCode == 'ar';
      double leading(Rect rect) => rtl ? 390 - rect.right : rect.left;
      double trailing(Rect rect) => rtl ? rect.left : 390 - rect.right;
      Rect rectOf(String key) => tester.getRect(find.byKey(ValueKey(key)));
      final l10n = tester.element(find.byType(BottomSheet)).l10n;

      for (final label in [
        l10n.readerFontSize,
        l10n.readerLineSpacing,
        l10n.readerTextAlignment,
        l10n.readerPageMargins,
        l10n.readerPageTurn,
      ]) {
        expect(leading(tester.getRect(find.text(label))), _gutter);
      }
      // Compact controls trail their label on the gutter, all one width.
      for (final key in _compactControls) {
        expect(trailing(rectOf(key)), _gutter, reason: key);
        expect(rectOf(key).width, rectOf(_compactControls.first).width);
        expect(
          rectOf(key).height,
          greaterThanOrEqualTo(AppSizes.buttonHeight),
        );
      }
      // Labeled choices span the gutters below their label.
      for (final (key, label) in [
        (_labeledControls[0], l10n.readerTextAlignment),
        (_labeledControls[1], l10n.readerPageTurn),
      ]) {
        final control = rectOf(key);
        final title = tester.getRect(find.text(label));
        expect(leading(control), _gutter, reason: key);
        expect(trailing(control), _gutter, reason: key);
        expect(control.top - title.bottom, AppSpacing.sm, reason: key);
      }
      expect(
        tester.getRect(find.text(l10n.readerTextAlignment)).top -
            rectOf('reader-line-height-control').bottom,
        AppSpacing.lg,
      );
      expect(
        tester.getRect(find.text(l10n.readerPageTurn)).top -
            rectOf('reader-margin-control').bottom,
        AppSpacing.lg,
      );
      // Small "A" leads, large "A" trails, mirrored in RTL.
      final decrease = rectOf('reader-text-scale-decrease');
      final increase = rectOf('reader-text-scale-increase');
      expect(leading(decrease), lessThan(leading(increase)));
      expect(trailing(increase), _gutter);
      // Glyph segments mirror with the control; Compact/Narrow lead.
      expect(
        leading(rectOf('reader-line-spacing-compact')),
        lessThan(leading(rectOf('reader-line-spacing-relaxed'))),
      );
      expect(
        leading(rectOf('reader-margin-narrow')),
        lessThan(leading(rectOf('reader-margin-wide'))),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [
    const Locale('en'),
    const Locale('ru'),
    const Locale('de'),
  ]) {
    testWidgets('labeled choices fit one segmented row at 390dp $locale', (
      tester,
    ) async {
      await tester.openSheet(locale: locale, size: const Size(390, 1100));
      final l10n = tester.element(find.byType(BottomSheet)).l10n;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reader-text-alignment-control')),
          matching: find.byType(SegmentedButton<ReaderTextAlignment>),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reader-page-turn-control')),
          matching: find.byType(SegmentedButton<ReaderPageTurnStyle>),
        ),
        findsOneWidget,
      );
      for (final label in [
        l10n.readerAlignNormal,
        l10n.readerAlignJustified,
        l10n.readerPageTurnHorizontalShort,
        l10n.readerPageTurnVerticalShort,
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(_lineCount(paragraph), 1, reason: label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      _expectNoTruncatedText(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [
    const Locale('en'),
    const Locale('ru'),
    const Locale('de'),
  ]) {
    testWidgets('2x text at 320dp reflows without overflow $locale', (
      tester,
    ) async {
      final cubit = await tester.openSheet(
        locale: locale,
        size: const Size(320, 720),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
      final l10n = tester.element(find.byType(BottomSheet)).l10n;
      const contentEnd = 320 - _gutter;
      _expectNoTruncatedText(tester);

      // Compact controls drop below their label, still on the gutter.
      for (final (key, label) in [
        (_compactControls[0], l10n.readerFontSize),
        (_compactControls[1], l10n.readerLineSpacing),
        (_compactControls[2], l10n.readerPageMargins),
      ]) {
        final control = tester.getRect(find.byKey(ValueKey(key)));
        expect(
          control.top - tester.getRect(find.text(label)).bottom,
          AppSpacing.sm,
          reason: key,
        );
        expect(control.right, contentEnd, reason: key);
        expect(control.left, greaterThanOrEqualTo(_gutter), reason: key);
      }
      // Labeled options keep 48dp, stay inside the gutters and wrap only
      // between words.
      for (final key in _labeledControls) {
        final control = find.byKey(ValueKey(key));
        expect(tester.getRect(control).left, _gutter);
        expect(tester.getRect(control).right, contentEnd);
        final buttons = find.descendant(
          of: control,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        expect(buttons, findsNWidgets(2));
        for (final button in buttons.evaluate()) {
          final box = button.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          expect(rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
          expect(rect.left, greaterThanOrEqualTo(_gutter));
          expect(rect.right, lessThanOrEqualTo(contentEnd));
        }
        for (final text in tester.widgetList<Text>(
          find.descendant(of: control, matching: find.byType(Text)),
        )) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: control, matching: find.text(text.data!)),
          );
          final words = text.data!.split(' ').length;
          expect(
            _lineCount(paragraph),
            lessThanOrEqualTo(words),
            reason: '${text.data} must not break inside a word',
          );
        }
      }

      final pageTurn = find.text(l10n.readerPageTurnVerticalShort);
      await tester.ensureVisible(pageTurn);
      await tester.pumpAndSettle();
      expect(pageTurn.hitTestable(), findsOneWidget);
      await tester.tap(pageTurn);
      await tester.pumpAndSettle();
      expect(
        cubit.state.effectiveAppearance.pageTurnStyle,
        ReaderPageTurnStyle.vertical,
      );
      final wide = find.byKey(const ValueKey('reader-margin-wide'));
      await tester.ensureVisible(wide);
      await tester.pumpAndSettle();
      await tester.tap(wide);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        cubit.state.effectiveAppearance.sideMargin,
        ReaderMarginPreset.wide.sideMargin,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

int _lineCount(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((box) => box.top.round()).toSet().length;
}

void _expectNoTruncatedText(WidgetTester tester) {
  final paragraphs = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"${paragraph.text.toPlainText()}" is truncated',
    );
  }
}

extension on WidgetTester {
  Future<ReaderAppearanceCubit> openSheet({
    required Locale locale,
    required Size size,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    final cubit = ReaderAppearanceCubit(
      preferencesService: preferences,
      sourceId: 'layout-source',
    );
    addTearDown(cubit.close);
    await pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showReaderAppearanceSheet(context),
                  child: const Text('Open'),
                ),
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
