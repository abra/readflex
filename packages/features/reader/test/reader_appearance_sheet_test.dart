import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';
import 'package:reader/src/reader_font_sheet.dart';
import 'package:reader/src/reader_layout_presets.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _sourceId = 'source-1';

void main() {
  late PreferencesService preferencesService;
  late ReaderAppearanceCubit cubit;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    cubit = ReaderAppearanceCubit(
      preferencesService: preferencesService,
      sourceId: _sourceId,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  testWidgets('renders compact appearance sheet without tabs or preview', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Layout'), findsNothing);
    expect(find.text('Snow'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Graphite'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
    expect(find.text('Font'), findsOneWidget);

    expect(find.byKey(const ValueKey('reader-font-picker')), findsOneWidget);
    // The swatch grid bleeds its 4dp ink inset past the gutter the Font row
    // sits on; the painted samples line up with the row.
    final fontPicker = tester.getRect(
      find.byKey(const ValueKey('reader-font-picker')),
    );
    final presets = tester.getRect(
      find.byKey(const ValueKey('reader-theme-presets')),
    );
    expect(fontPicker.left - presets.left, AppSpacing.xs);
    expect(presets.right - fontPicker.right, AppSpacing.xs);
    expect(find.text('Literata'), findsOneWidget);
    expect(find.text('PT Serif'), findsNothing);
    expect(find.text('Open Sans'), findsNothing);
    expect(find.text('Geist'), findsNothing);
    expect(find.byKey(const ValueKey('reader-font-page-dots')), findsNothing);
    expect(find.text('A-'), findsNothing);
    expect(find.text('A+'), findsNothing);
    expect(find.text('Font size'), findsOneWidget);
    final textScaleControl = find.byKey(
      const ValueKey('reader-text-scale-control'),
    );
    expect(
      find.descendant(of: textScaleControl, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(of: textScaleControl, matching: find.text('A')),
      findsNWidgets(2),
    );
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.byIcon(AppIcons.remove), findsNothing);
    expect(find.byIcon(AppIcons.add), findsNothing);
    expect(find.byIcon(AppIcons.alignEnd), findsNothing);
    for (final preset in ReaderLineSpacingPreset.values) {
      expect(
        find.byKey(ValueKey('reader-line-spacing-${preset.name}')),
        findsOneWidget,
      );
    }
    for (final preset in ReaderMarginPreset.values) {
      expect(
        find.byKey(ValueKey('reader-margin-${preset.name}')),
        findsOneWidget,
      );
    }
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Justified'), findsOneWidget);
    expect(find.text('Horizontal'), findsOneWidget);
    expect(find.text('Vertical'), findsOneWidget);
    expect(find.text('Page turn'), findsOneWidget);
    expect(find.text('Page margins'), findsOneWidget);
    expect(find.text('Text alignment'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('reader-text-scale-control'))),
      tester.getSize(find.byKey(const ValueKey('reader-line-height-control'))),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('reader-text-scale-control'))),
      tester.getSize(find.byKey(const ValueKey('reader-margin-control'))),
    );
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('hides page turn controls for vertical article reader', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit, showPageTurnControls: false);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Font size'), findsOneWidget);
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.text('Page turn'), findsNothing);
    expect(find.byIcon(AppIcons.pageTurnHorizontal), findsNothing);
    expect(find.byIcon(AppIcons.pageTurnVertical), findsNothing);
    expect(find.text('Horizontal'), findsNothing);
    expect(find.text('Vertical'), findsNothing);
    expect(find.text('Justified'), findsOneWidget);
    expect(find.text('Page margins'), findsOneWidget);
    expect(find.text('Text alignment'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  group('PDF pages', () {
    testWidgets('swap text controls for margins and page colors', (
      tester,
    ) async {
      await tester.openAppearanceSheet(cubit, pdfControls: true);

      expect(find.text('Appearance'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reader-theme-presets')),
        findsOneWidget,
      );
      for (final text in [
        'Margins',
        'Whole page',
        'Trimmed',
        'Page colors',
        'Original',
        'Page turn',
        'Horizontal',
        'Vertical',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // "Theme" names both the swatch section and a page colors option.
      expect(find.text('Theme'), findsNWidgets(2));
      for (final text in [
        'Font',
        'Font size',
        'Line spacing',
        'Text alignment',
        'Page margins',
      ]) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(find.byKey(const ValueKey('reader-font-picker')), findsNothing);
      expect(find.byType(ReaderFontSheet), findsNothing);
    });

    testWidgets('start trimmed in theme colors and save choices per book', (
      tester,
    ) async {
      await tester.openAppearanceSheet(cubit, pdfControls: true);
      AppChoiceControl<T> control<T>(String key) =>
          tester.widget<AppChoiceControl<T>>(find.byKey(ValueKey(key)));

      expect(control<bool>('reader-pdf-margins-control').selected, isTrue);
      expect(
        control<ReaderPageColors>('reader-pdf-page-colors-control').selected,
        ReaderPageColors.theme,
      );
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Whole page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      expect(control<bool>('reader-pdf-margins-control').selected, isFalse);
      expect(
        control<ReaderPageColors>('reader-pdf-page-colors-control').selected,
        ReaderPageColors.original,
      );
      final saved = preferencesService.readerAppearanceOverrideFor(_sourceId);
      expect(saved?.trimPageMargins, isFalse);
      expect(saved?.pageColors, ReaderPageColors.original);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(control<bool>('reader-pdf-margins-control').selected, isTrue);
      expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    });

    testWidgets('choices announce their names and selection', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.openAppearanceSheet(cubit, pdfControls: true);

      for (final (label, selected) in [
        ('Whole page', false),
        ('Trimmed', true),
        ('Original', false),
      ]) {
        final node = tester.getSemantics(
          find
              .ancestor(of: find.text(label), matching: find.byType(Semantics))
              .first,
        );
        expect(
          node.flagsCollection.isSelected,
          selected ? Tristate.isTrue : Tristate.isFalse,
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('large text keeps every PDF choice readable', (tester) async {
      await tester.openAppearanceSheet(
        cubit,
        pdfControls: true,
        textScaler: const TextScaler.linear(2),
      );
      for (final text in ['Whole page', 'Trimmed', 'Original']) {
        final finder = find.text(text);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
          reason: text,
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('compact rows', () {
    const compactControls = [
      'reader-text-scale-control',
      'reader-line-height-control',
      'reader-margin-control',
    ];
    const compactLabels = ['Font size', 'Line spacing', 'Page margins'];

    for (final direction in TextDirection.values) {
      testWidgets('controls take the end half, on the split of the choices '
          'below ($direction)', (tester) async {
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.openAppearanceSheet(cubit, textDirection: direction);
        final ltr = direction == TextDirection.ltr;
        final column = tester.getRect(
          find.byKey(const ValueKey('reader-text-alignment-control')),
        );
        for (final key in compactControls) {
          final control = tester.getRect(find.byKey(ValueKey(key)));
          expect(control.width, closeTo(column.width / 2, 1e-6), reason: key);
          expect(
            ltr ? control.left : control.right,
            closeTo(column.center.dx, 1e-6),
            reason: key,
          );
          expect(
            ltr ? control.right : control.left,
            ltr ? column.right : column.left,
          );
        }
        final rows = [
          tester.getRect(find.byKey(const ValueKey('reader-font-picker'))),
          for (final key in compactControls)
            tester.getRect(find.byKey(ValueKey(key))),
        ];
        for (var i = 1; i < rows.length; i++) {
          expect(rows[i].top - rows[i - 1].bottom, AppSpacing.sm);
        }
        for (final label in compactLabels) {
          final text = tester.getRect(find.text(label));
          expect(
            ltr ? text.left : text.right,
            ltr ? column.left : column.right,
          );
          expect(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(AppSettingsSection),
            ),
            findsNothing,
            reason: label,
          );
        }
      });
    }

    testWidgets('a narrow sheet puts every control under its caption', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.openAppearanceSheet(cubit, locale: const Locale('ru'));
      final column = tester.getRect(
        find.byKey(const ValueKey('reader-text-alignment-control')),
      );
      final captions = [
        'Размер текста',
        'Межстрочный интервал',
        'Поля страницы',
      ];
      for (final (index, key) in compactControls.indexed) {
        final control = tester.getRect(find.byKey(ValueKey(key)));
        expect(control.width, column.width, reason: key);
        final caption = find.text(captions[index]);
        expect(
          find.ancestor(of: caption, matching: find.byType(AppSettingsSection)),
          findsOneWidget,
        );
        expect(
          tester.renderObject<RenderParagraph>(caption).didExceedMaxLines,
          isFalse,
        );
        expect(tester.getRect(caption).bottom, lessThan(control.top));
      }
      // Stacked rows keep the 16dp rhythm of the captioned choices.
      final fontRow = tester.getRect(
        find.byKey(const ValueKey('reader-font-picker')),
      );
      expect(
        tester.getTopLeft(find.text('Размер текста')).dy - fontRow.bottom,
        AppSpacing.lg,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a label that would need a third line stacks all three rows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Below the large-text rule: 1.28 x 14 < 18.
      const scale = TextScaler.linear(1.28);
      await tester.openAppearanceSheet(cubit, textScaler: scale);
      for (final label in compactLabels) {
        expect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AppSettingsSection),
          ),
          findsNothing,
          reason: label,
        );
      }
      // The test font's square glyphs break "Межстрочный" over three lines
      // in the half row.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.openAppearanceSheet(
        cubit,
        locale: const Locale('ru'),
        textScaler: scale,
      );
      for (final label in [
        'Размер текста',
        'Межстрочный интервал',
        'Поля страницы',
      ]) {
        expect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AppSettingsSection),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('alignment and page turn are captioned choices', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.openAppearanceSheet(cubit);
      for (final caption in ['Theme', 'Text alignment', 'Page turn']) {
        expect(
          find.ancestor(
            of: find.text(caption),
            matching: find.byType(AppSettingsSection),
          ),
          findsOneWidget,
          reason: caption,
        );
        expect(
          tester.getSemantics(find.text(caption)).flagsCollection.isHeader,
          isTrue,
          reason: caption,
        );
      }
      final margins = tester.getRect(
        find.byKey(const ValueKey('reader-margin-control')),
      );
      final alignment = tester.getRect(find.text('Text alignment'));
      final pageTurn = tester.getRect(find.text('Page turn'));
      final alignmentControl = tester.getRect(
        find.byKey(const ValueKey('reader-text-alignment-control')),
      );
      expect(alignment.top - margins.bottom, AppSpacing.lg);
      expect(pageTurn.top - alignmentControl.bottom, AppSpacing.lg);
      semantics.dispose();
    });
  });

  testWidgets('theme swatches persist reader theme ids', (tester) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Snow'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.themeId, 'snow');
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.themeId,
      'snow',
    );
  });

  testWidgets('legacy white theme id selects Snow swatch', (tester) async {
    const legacySourceId = 'legacy-source';
    await preferencesService.setReaderAppearanceOverride(
      legacySourceId,
      const ReaderAppearanceOverride(themeId: 'white'),
    );
    final legacyCubit = ReaderAppearanceCubit(
      preferencesService: preferencesService,
      sourceId: legacySourceId,
    );
    addTearDown(legacyCubit.close);

    await tester.openAppearanceSheet(legacyCubit);

    final snowLabel = tester.widget<Text>(find.text('Snow'));
    final primary = Theme.of(
      tester.element(find.text('Snow')),
    ).colorScheme.primary;
    expect(snowLabel.style?.color, primary);
  });

  testWidgets('font selector shows all presets and persists selected font', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    await tester.openFontStep();

    await tester.tap(find.text('PT Serif'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.fontId, 'ptSerif');
    expect(find.text('PT Serif').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
    expect(find.text('Appearance').hitTestable(), findsNothing);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.fontId,
      'ptSerif',
    );
  });

  testWidgets('font selector keeps Open Sans readable without dots', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    await tester.openFontStep();

    final openSansLabel = tester.widget<Text>(
      find.byKey(const ValueKey('reader-font-sans')),
    );

    expect(openSansLabel.data, 'Open Sans');
    // Labels may wrap, but must never shrink or ellipsize the chosen font.
    expect(openSansLabel.maxLines, isNull);
    expect(openSansLabel.overflow, isNull);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('reader-font-sans')),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
    expect(
      openSansLabel.style?.fontSize,
      tester
          .element(find.byKey(const ValueKey('reader-font-sans')))
          .text
          .labelLarge
          .fontSize,
    );
    expect(find.byKey(const ValueKey('reader-font-page-dots')), findsNothing);
  });

  testWidgets('appearance sheet does not reserve fixed tab body height', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(_fixedTabBodyHeightFinder(), findsNothing);
  });

  testWidgets('line spacing presets preview and persist exact values', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(
      find.byKey(const ValueKey('reader-line-height-value')),
      findsNothing,
    );
    expect(find.text('1.6'), findsNothing);
    expect(_selectedLineSpacing(tester), ReaderLineSpacingPreset.normal);

    for (final preset in [
      ReaderLineSpacingPreset.relaxed,
      ReaderLineSpacingPreset.compact,
      ReaderLineSpacingPreset.normal,
    ]) {
      await tester.tap(
        find.byKey(ValueKey('reader-line-spacing-${preset.name}')),
      );
      await tester.pump();

      expect(cubit.state.effectiveAppearance.lineHeight, preset.lineHeight);
      expect(_selectedLineSpacing(tester), preset);

      await tester.pump(const Duration(milliseconds: 300));

      // Normal equals the inherited value, so it clears the override.
      expect(
        preferencesService.readerAppearanceOverrideFor(_sourceId)?.lineHeight,
        preset == ReaderLineSpacingPreset.normal ? isNull : preset.lineHeight,
        reason: preset.name,
      );
    }
  });

  testWidgets('margin presets preview and persist exact values', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('reader-margin-value')), findsNothing);
    expect(find.text('8%'), findsNothing);
    expect(_selectedMargin(tester), ReaderMarginPreset.medium);

    for (final preset in [
      ReaderMarginPreset.wide,
      ReaderMarginPreset.narrow,
      ReaderMarginPreset.medium,
    ]) {
      await tester.tap(find.byKey(ValueKey('reader-margin-${preset.name}')));
      await tester.pump();

      expect(cubit.state.effectiveAppearance.sideMargin, preset.sideMargin);
      expect(_selectedMargin(tester), preset);

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        preferencesService.readerAppearanceOverrideFor(_sourceId)?.sideMargin,
        preset == ReaderMarginPreset.medium ? isNull : preset.sideMargin,
        reason: preset.name,
      );
    }
  });

  testWidgets('in-between stored values select the nearest preset', (
    tester,
  ) async {
    final lineHeights = {
      1.0: ReaderLineSpacingPreset.compact,
      1.2: ReaderLineSpacingPreset.compact,
      1.45: ReaderLineSpacingPreset.compact,
      1.5: ReaderLineSpacingPreset.normal,
      1.6 + 0.1: ReaderLineSpacingPreset.normal,
      1.75: ReaderLineSpacingPreset.relaxed,
      2.0: ReaderLineSpacingPreset.relaxed,
    };
    final margins = {
      2.0: ReaderMarginPreset.narrow,
      5.0: ReaderMarginPreset.narrow,
      6.0: ReaderMarginPreset.medium,
      9.0: ReaderMarginPreset.medium,
      10.0: ReaderMarginPreset.medium,
      11.0: ReaderMarginPreset.wide,
      14.0: ReaderMarginPreset.wide,
    };
    await tester.openAppearanceSheet(cubit);

    for (final entry in lineHeights.entries) {
      // The cubit listens from setUp's zone; let its delivery run.
      await tester.runAsync(
        () => preferencesService.update(
          (prefs) => prefs.copyWith(readerLineHeight: entry.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.effectiveAppearance.lineHeight, entry.key);
      expect(_selectedLineSpacing(tester), entry.value, reason: '${entry.key}');
    }
    for (final entry in margins.entries) {
      // The cubit listens from setUp's zone; let its delivery run.
      await tester.runAsync(
        () => preferencesService.update(
          (prefs) => prefs.copyWith(readerSideMargin: entry.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.effectiveAppearance.sideMargin, entry.key);
      expect(_selectedMargin(tester), entry.value, reason: '${entry.key}');
    }
    // Showing a nearest preset never rewrites the stored value.
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(preferencesService.current.readerLineHeight, 2.0);
    expect(preferencesService.current.readerSideMargin, 14.0);
  });

  testWidgets('tapping the nearest preset applies its exact value', (
    tester,
  ) async {
    await preferencesService.update(
      (prefs) => prefs.copyWith(readerLineHeight: 1.5, readerSideMargin: 6),
    );
    await tester.pump();
    await tester.openAppearanceSheet(cubit);

    expect(_selectedLineSpacing(tester), ReaderLineSpacingPreset.normal);
    expect(_selectedMargin(tester), ReaderMarginPreset.medium);

    await tester.tap(find.byKey(const ValueKey('reader-line-spacing-normal')));
    await tester.tap(find.byKey(const ValueKey('reader-margin-medium')));
    await tester.pump();

    expect(cubit.state.effectiveAppearance.lineHeight, 1.6);
    expect(cubit.state.effectiveAppearance.sideMargin, 8);
    expect(_selectedLineSpacing(tester), ReaderLineSpacingPreset.normal);

    await tester.pump(const Duration(milliseconds: 300));

    final override = preferencesService.readerAppearanceOverrideFor(_sourceId);
    expect(override?.lineHeight, 1.6);
    expect(override?.sideMargin, 8);
  });

  testWidgets('tapping the exact selected preset writes nothing', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    final states = <ReaderAppearanceState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    await tester.tap(find.byKey(const ValueKey('reader-line-spacing-normal')));
    await tester.tap(find.byKey(const ValueKey('reader-margin-medium')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(states, isEmpty);
    expect(cubit.state.hasOverride, isFalse);
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
  });

  testWidgets('alignment offers labeled Normal and Justified only', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    final control = find.byKey(const ValueKey('reader-text-alignment-control'));

    expect(find.text('Start'), findsNothing);
    expect(find.text('End'), findsNothing);
    expect(find.text('Justify'), findsNothing);
    expect(find.byIcon(AppIcons.alignEnd), findsNothing);
    expect(
      find.descendant(of: control, matching: find.byIcon(AppIcons.alignStart)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: control,
        matching: find.byIcon(AppIcons.alignJustify),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppChoiceControl<ReaderTextAlignment>>(control)
          .options
          .map((option) => option.value),
      [ReaderTextAlignment.start, ReaderTextAlignment.justify],
    );
    expect(_selectedAlignment(tester), ReaderTextAlignment.start);

    await tester.tap(find.text('Justified'));
    await tester.pumpAndSettle();

    expect(
      cubit.state.effectiveAppearance.textAlignment,
      ReaderTextAlignment.justify,
    );
    expect(_selectedAlignment(tester), ReaderTextAlignment.justify);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textAlignment,
      ReaderTextAlignment.justify,
    );

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(
      cubit.state.effectiveAppearance.textAlignment,
      ReaderTextAlignment.start,
    );
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
  });

  testWidgets('page turn offers labeled horizontal and vertical choices', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    final control = find.byKey(const ValueKey('reader-page-turn-control'));
    final selectedForeground = tester
        .element(control)
        .colors
        .selectedControlForeground;

    expect(
      find.descendant(of: control, matching: find.text('Horizontal')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: control, matching: find.text('Vertical')),
      findsOneWidget,
    );
    expect(find.text('Instant'), findsNothing);
    // Labeled choices carry no extra tooltip.
    expect(find.byTooltip('Horizontal page turn'), findsNothing);
    expect(find.byTooltip('Vertical page turn'), findsNothing);
    expect(
      IconTheme.of(
        tester.element(find.byIcon(AppIcons.pageTurnHorizontal)),
      ).color,
      selectedForeground,
    );
    expect(
      IconTheme.of(
        tester.element(find.byIcon(AppIcons.pageTurnVertical)),
      ).color,
      isNot(selectedForeground),
    );

    await tester.ensureVisible(find.text('Vertical'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vertical'));
    await tester.pumpAndSettle();

    expect(
      IconTheme.of(
        tester.element(find.byIcon(AppIcons.pageTurnVertical)),
      ).color,
      selectedForeground,
    );
    expect(
      cubit.state.effectiveAppearance.pageTurnStyle,
      ReaderPageTurnStyle.vertical,
    );
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.pageTurnStyle,
      ReaderPageTurnStyle.vertical,
    );

    await tester.tap(find.text('Horizontal'));
    await tester.pumpAndSettle();

    expect(
      cubit.state.effectiveAppearance.pageTurnStyle,
      ReaderPageTurnStyle.horizontal,
    );
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
  });

  testWidgets('glyph segments ink selected and idle states like icons', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    final colors = tester.element(find.byType(BottomSheet)).colors;
    Color? ink(String key) =>
        IconTheme.of(tester.element(find.byKey(ValueKey(key)))).color;

    expect(ink('reader-line-spacing-normal'), colors.selectedControlForeground);
    expect(ink('reader-line-spacing-compact'), colors.onSurfaceVariant);
    expect(ink('reader-margin-medium'), colors.selectedControlForeground);
    expect(ink('reader-margin-wide'), colors.onSurfaceVariant);
    // Same pair as the icon segments of AppChoiceControl.
    expect(
      ink('reader-line-spacing-normal'),
      IconTheme.of(
        tester.element(find.byIcon(AppIcons.pageTurnHorizontal)),
      ).color,
    );
    final selectedFill = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('reader-line-spacing-normal')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(selectedFill.color, colors.selectedControlBackground);
    // The selected fill spans the whole 48dp segment.
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('reader-line-spacing-normal')),
                  matching: find.byType(TextButton),
                )
                .first,
          )
          .height,
      AppSizes.buttonHeight,
    );
  });

  testWidgets('persists font changes and resets source override from header', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    await tester.openFontStep();

    await tester.tap(find.text('PT Serif'));
    await tester.pumpAndSettle();

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.fontId,
      'ptSerif',
    );

    await tester.tap(find.byTooltip('Back').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset').hitTestable());
    await tester.pumpAndSettle();

    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(cubit.state.hasOverride, isFalse);
  });

  testWidgets('text size buttons preview and persist source override', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('100%'), findsOneWidget);
    final primary = Theme.of(
      tester.element(find.byKey(const ValueKey('reader-text-scale-value'))),
    ).colorScheme.primary;
    expect(
      _stepperValueText(
        tester,
        const ValueKey('reader-text-scale-value'),
      ).style?.color,
      isNot(primary),
    );

    await tester.tap(find.byKey(const ValueKey('reader-text-scale-increase')));
    await tester.pump();

    expect(cubit.state.effectiveAppearance.textScale, closeTo(1.05, 0.001));
    expect(find.text('105%'), findsOneWidget);
    expect(
      _stepperValueText(
        tester,
        const ValueKey('reader-text-scale-value'),
      ).style?.color,
      primary,
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      closeTo(1.05, 0.001),
    );

    await tester.tap(find.text('105%'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.textScale, 1);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      isNull,
    );
    expect(
      _stepperValueText(
        tester,
        const ValueKey('reader-text-scale-value'),
      ).style?.color,
      isNot(primary),
    );
  });

  testWidgets('text size buttons override inherited global scale', (
    tester,
  ) async {
    await preferencesService.update(
      (prefs) => prefs.copyWith(readerTextScale: 1.15),
    );
    await tester.pump();

    await tester.openAppearanceSheet(cubit);

    final resetButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reset'),
    );
    expect(resetButton.onPressed, isNull);
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(cubit.state.effectiveAppearance.textScale, 1.15);

    await tester.tap(find.byKey(const ValueKey('reader-text-scale-decrease')));
    await tester.pump();

    expect(cubit.state.effectiveAppearance.textScale, closeTo(1.10, 0.001));

    await tester.pump(const Duration(milliseconds: 300));

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      closeTo(1.10, 0.001),
    );
  });

  testWidgets('line spacing follows the inherited value until overridden', (
    tester,
  ) async {
    await preferencesService.update(
      (prefs) => prefs.copyWith(readerLineHeight: 1.8),
    );
    await tester.pump();

    await tester.openAppearanceSheet(cubit);

    expect(_selectedLineSpacing(tester), ReaderLineSpacingPreset.relaxed);

    await tester.tap(find.byKey(const ValueKey('reader-line-spacing-normal')));
    await tester.pump();

    expect(_selectedLineSpacing(tester), ReaderLineSpacingPreset.normal);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.lineHeight,
      1.6,
    );

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(_selectedLineSpacing(tester), ReaderLineSpacingPreset.relaxed);
  });

  testWidgets('restores reader chrome after appearance sheet is fully hidden', (
    tester,
  ) async {
    final uiCubit = ReaderUiCubit()..showChrome();
    addTearDown(uiCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: uiCubit),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      final readerUiCubit = context.read<ReaderUiCubit>();
                      readerUiCubit.beginAppearanceSheet();
                      showReaderAppearanceSheet(
                        context,
                        onFullyHidden: readerUiCubit.appearanceSheetHidden,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(uiCubit.state.chromeVisible, isFalse);
    expect(uiCubit.state.appearanceSheetVisible, isTrue);

    await tester.openFontStep();
    await tester.tap(find.byTooltip('Back').hitTestable());
    await tester.pumpAndSettle();
    expect(uiCubit.state.chromeVisible, isFalse);
    expect(uiCubit.state.appearanceSheetVisible, isTrue);
    await tester.openFontStep();

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(uiCubit.state.chromeVisible, isFalse);
    expect(uiCubit.state.appearanceSheetVisible, isTrue);

    await tester.pumpAndSettle();

    expect(uiCubit.state.chromeVisible, isTrue);
    expect(uiCubit.state.overlay, ReaderOverlay.none);
  });

  for (final book in [true, false]) {
    testWidgets('font flow keeps the content-sized height (book=$book)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.openAppearanceSheet(cubit, showPageTurnControls: book);
      final bounds = tester.getRect(find.byType(BottomSheet));
      await tester.openFontStep();
      expect(tester.getRect(find.byType(BottomSheet)), bounds);
      expect(find.text('Appearance').hitTestable(), findsNothing);
      expect(find.semantics.byLabel('Reset'), findsNothing);
      for (final preset in ReaderFontPreset.values) {
        final sample = find.byKey(ValueKey('reader-font-sample-${preset.id}'));
        expect(sample.hitTestable(), findsOneWidget);
        expect(
          tester.widget<Text>(sample).style?.fontFamily,
          preset.fontFamily,
        );
        expect(
          tester
              .getSize(find.byKey(ValueKey('reader-font-option-${preset.id}')))
              .height,
          greaterThanOrEqualTo(48),
        );
      }
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ReaderFontSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, 0);
      for (final preset in [ReaderFontPreset.sans, ReaderFontPreset.geist]) {
        await tester.tap(find.byKey(ValueKey('reader-font-${preset.id}')));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(BottomSheet)), bounds);
        expect(cubit.state.effectiveAppearance.fontId, preset.id);
        expect(
          tester.getSemantics(
            find.byKey(ValueKey('reader-font-option-${preset.id}')),
          ),
          matchesSemantics(
            label: preset.label,
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
            isFocusable: true,
          ),
        );
      }
      await tester.tap(find.byTooltip('Back').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(BottomSheet)), bounds);
      expect(find.text('Geist').hitTestable(), findsOneWidget);
      expect(find.text('Page turn'), book ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'theme samples, Font row and font options share the 24dp gutter $locale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.openAppearanceSheet(cubit, locale: locale);
        final rtl = locale.languageCode == 'ar';
        final l10n = tester.element(find.byType(BottomSheet)).l10n;
        double leading(Rect rect) => rtl ? 390 - rect.right : rect.left;
        double trailing(Rect rect) => rtl ? rect.left : 390 - rect.right;

        expect(leading(tester.getRect(find.text(l10n.readerTheme))), 24);
        Rect sample(ReaderThemePreset preset) => tester.getRect(
          find
              .descendant(
                of: find.byKey(ValueKey('reader-theme-swatch-${preset.id}')),
                matching: find.byType(Container),
              )
              .first,
        );
        Rect tile(ReaderThemePreset preset) => tester.getRect(
          find.byKey(ValueKey('reader-theme-swatch-${preset.id}')),
        );
        final first = ReaderThemePreset.values.first;
        // Sample border on the gutter; the ink tile bleeds 4dp past it.
        expect(leading(sample(first)), AppSpacing.xl);
        expect(leading(tile(first)), AppSpacing.xl - AppSpacing.xs);
        expect(
          ReaderThemePreset.values.map(sample).map(trailing).reduce(math.min),
          AppSpacing.xl,
        );
        expect(
          ReaderThemePreset.values.map(tile).map(trailing).reduce(math.min),
          AppSpacing.xl - AppSpacing.xs,
        );

        final fontRow = find.byKey(const ValueKey('reader-font-picker'));
        expect(leading(tester.getRect(fontRow)), AppSpacing.xl);
        expect(trailing(tester.getRect(fontRow)), AppSpacing.xl);
        expect(
          leading(
            tester.getRect(
              find.descendant(
                of: fontRow,
                matching: find.text(l10n.readerFont),
              ),
            ),
          ),
          AppSpacing.xl,
        );
        expect(
          leading(tester.getRect(find.text(l10n.readerFontSize))),
          AppSpacing.xl,
        );

        await tester.openFontStep();
        final selected = ReaderFontPreset.fromId(
          cubit.state.effectiveAppearance.fontId,
        );
        final option = find.byKey(
          ValueKey('reader-font-option-${selected.id}'),
        );
        final text = tester.getRect(
          find.byKey(ValueKey('reader-font-${selected.id}')),
        );
        final check = tester.getRect(
          find.descendant(of: option, matching: find.byIcon(AppIcons.check)),
        );
        expect(leading(text), AppSpacing.xl);
        expect(check.size, const Size.square(AppIconSize.sm));
        expect(trailing(check), AppSpacing.xl);
        // The option's fill keeps its 8dp ink inset on both sides.
        expect(leading(tester.getRect(option)), AppSpacing.xl - AppSpacing.sm);
        expect(trailing(tester.getRect(option)), AppSpacing.xl - AppSpacing.sm);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('system Back returns from Font before closing the flow', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    await tester.openFontStep();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Appearance').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Close on Font dismisses the entire flow', (tester) async {
    await tester.openAppearanceSheet(cubit);
    await tester.openFontStep();
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('font navigation supports RTL and reduced motion', (
    tester,
  ) async {
    await tester.openAppearanceSheet(
      cubit,
      locale: const Locale('ar'),
      disableAnimations: true,
    );
    expect(find.byIcon(AppIcons.chevronLeft), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reader-font-picker')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('reader-font-sans')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reader-font-sans')));
    await tester.pumpAndSettle();
    final back = tester.element(find.byType(ReaderFontSheet)).l10n.commonBack;
    await tester.tap(find.byTooltip(back).hitTestable());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('reader-font-picker')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('theme swatches are selectable ink tiles with sample colors', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.openAppearanceSheet(cubit);
    final context = tester.element(find.text('Snow'));
    final l10n = context.l10n;
    expect(
      find.text(l10n.readerAppearanceSample),
      findsNWidgets(ReaderThemePreset.values.length),
    );
    final paper = find.byKey(const ValueKey('reader-theme-swatch-paper'));
    final snow = find.byKey(const ValueKey('reader-theme-swatch-snow'));
    final paperNode = tester.getSemantics(paper);
    expect(paperNode.flagsCollection.isButton, isTrue);
    expect(paperNode.flagsCollection.isSelected, Tristate.isTrue);
    expect(paperNode.label, 'Paper');
    expect(
      tester.getSemantics(snow).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    expect(tester.getSize(paper).height, greaterThanOrEqualTo(48));
    expect(
      find.descendant(of: paper, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    // Only the ring and the name mark the selection: no tinted block.
    for (final swatch in [paper, snow]) {
      final material = tester.widget<Material>(
        find.descendant(of: swatch, matching: find.byType(Material)).first,
      );
      expect(material.type, MaterialType.transparency);
    }
    BoxDecoration sample(Finder swatch) =>
        tester
                .widget<Container>(
                  find
                      .descendant(of: swatch, matching: find.byType(Container))
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(
      sample(paper).color,
      ReaderThemePreset.paper.data.backgroundColor,
    );
    final ring = sample(paper).border! as Border;
    expect(ring.top.color, context.actionForeground);
    expect(ring.top.width, 2);
    final idle = sample(snow).border! as Border;
    expect(idle.top.color, context.appColors.divider);
    expect(idle.top.width, 1);
    final paperLabel = tester.widget<Text>(find.text('Paper')).style;
    expect(paperLabel?.color, context.actionForeground);
    expect(paperLabel?.fontWeight, FontWeight.w600);
    final snowLabel = tester.widget<Text>(find.text('Snow')).style;
    expect(snowLabel?.color, context.colors.onSurfaceVariant);
    expect(snowLabel?.fontWeight, FontWeight.w400);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('theme sample text is localized', (tester) async {
    await tester.openAppearanceSheet(cubit, locale: const Locale('ru'));
    final l10n = tester.element(find.byType(BottomSheet)).l10n;
    expect(l10n.readerAppearanceSample, isNot('Aa'));
    expect(
      find.text(l10n.readerAppearanceSample),
      findsNWidgets(ReaderThemePreset.values.length),
    );
    expect(find.text('Aa'), findsNothing);
  });

  testWidgets('font options use fill and check without an extra border', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    await tester.openFontStep();
    for (final preset in ReaderFontPreset.values) {
      final option = find.byKey(ValueKey('reader-font-option-${preset.id}'));
      final material = tester.widget<Material>(
        find.descendant(of: option, matching: find.byType(Material)).first,
      );
      expect(
        (material.shape! as RoundedRectangleBorder).side,
        BorderSide.none,
        reason: preset.id,
      );
    }
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });

  testWidgets('every appearance segment exposes its name and selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.openAppearanceSheet(cubit);
    final l10n = tester.element(find.byType(BottomSheet)).l10n;
    final lineSpacing = {
      ReaderLineSpacingPreset.compact: l10n.readerLineSpacingCompact,
      ReaderLineSpacingPreset.normal: l10n.readerLineSpacingNormal,
      ReaderLineSpacingPreset.relaxed: l10n.readerLineSpacingRelaxed,
    };
    final margins = {
      ReaderMarginPreset.narrow: l10n.readerMarginsNarrow,
      ReaderMarginPreset.medium: l10n.readerMarginsMedium,
      ReaderMarginPreset.wide: l10n.readerMarginsWide,
    };
    void expectGlyphSegments({
      required ReaderLineSpacingPreset selectedSpacing,
      required ReaderMarginPreset selectedMargin,
    }) {
      for (final entry in lineSpacing.entries) {
        expect(
          tester.getSemantics(
            find.byKey(ValueKey('reader-line-spacing-${entry.key.name}')),
          ),
          isSemantics(
            label: '',
            tooltip: entry.value,
            isButton: true,
            isEnabled: true,
            hasSelectedState: true,
            isSelected: entry.key == selectedSpacing,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
          reason: entry.value,
        );
      }
      for (final entry in margins.entries) {
        expect(
          tester.getSemantics(
            find.byKey(ValueKey('reader-margin-${entry.key.name}')),
          ),
          isSemantics(
            label: '',
            tooltip: entry.value,
            isButton: true,
            isEnabled: true,
            hasSelectedState: true,
            isSelected: entry.key == selectedMargin,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
          reason: entry.value,
        );
      }
    }

    expectGlyphSegments(
      selectedSpacing: ReaderLineSpacingPreset.normal,
      selectedMargin: ReaderMarginPreset.medium,
    );
    for (final (label, selected) in [
      (l10n.readerAlignNormal, true),
      (l10n.readerAlignJustified, false),
      (l10n.readerPageTurnHorizontalShort, true),
      (l10n.readerPageTurnVerticalShort, false),
    ]) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(
          label: label,
          isButton: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: selected,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
        reason: label,
      );
    }
    for (final (key, label) in [
      ('reader-text-scale-decrease', l10n.readerDecreaseTextSize),
      ('reader-text-scale-increase', l10n.readerIncreaseTextSize),
    ]) {
      // The "A" glyph stays out of the name.
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text('A'),
          ),
        ),
        isSemantics(
          label: label,
          tooltip: label,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }
    expect(
      tester.getSemantics(find.text('100%')),
      isSemantics(
        label: l10n.readerTextSize,
        value: '100%',
        tooltip: l10n.readerResetTextSize,
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('reader-line-spacing-compact')));
    await tester.tap(find.byKey(const ValueKey('reader-margin-wide')));
    await tester.tap(find.byKey(const ValueKey('reader-text-scale-increase')));
    await tester.pumpAndSettle();

    expectGlyphSegments(
      selectedSpacing: ReaderLineSpacingPreset.compact,
      selectedMargin: ReaderMarginPreset.wide,
    );
    expect(
      tester.getSemantics(find.text('105%')),
      isSemantics(label: l10n.readerTextSize, value: '105%'),
    );
    semantics.dispose();
  });

  testWidgets('appearance controls keep named 48dp targets', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.openAppearanceSheet(cubit);

    for (final key in [
      'reader-text-scale-decrease',
      'reader-text-scale-increase',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))),
        const Size.square(AppSizes.buttonHeight),
      );
    }
    expect(
      tester
          .getSize(find.byKey(const ValueKey('reader-text-scale-value')))
          .height,
      AppSizes.buttonHeight,
    );
    for (final key in [
      for (final preset in ReaderLineSpacingPreset.values)
        'reader-line-spacing-${preset.name}',
      for (final preset in ReaderMarginPreset.values)
        'reader-margin-${preset.name}',
    ]) {
      final segment = tester.getSize(
        find
            .ancestor(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(TextButton),
            )
            .first,
      );
      expect(segment.width, greaterThanOrEqualTo(AppSizes.buttonHeight));
      expect(segment.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
    }
    for (final label in ['Normal', 'Justified', 'Horizontal', 'Vertical']) {
      // A segment, or an outlined option once the labels need more room.
      final option = tester.getSize(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first,
      );
      expect(option.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('text size steps are small and large serif A glyphs', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);
    final colors = tester.element(find.byType(BottomSheet)).colors;
    final small = _textSizeGlyph(tester, 'reader-text-scale-decrease');
    final large = _textSizeGlyph(tester, 'reader-text-scale-increase');

    expect(small.data, 'A');
    expect(large.data, 'A');
    for (final glyph in [small, large]) {
      expect(glyph.style?.fontFamily, ReaderFontPreset.serif.fontFamily);
      expect(glyph.style?.color, colors.onSurfaceVariant);
    }
    expect(small.style?.fontSize, 14);
    expect(large.style?.fontSize, 22);
    // The percentage between them is a muted caption.
    final value = _stepperValueText(
      tester,
      const ValueKey('reader-text-scale-value'),
    );
    expect(value.data, '100%');
    expect(
      value.style?.fontSize,
      tester.element(find.text('100%')).text.bodySmall.fontSize,
    );
    expect(value.style?.color, colors.onSurfaceVariant);
    expect(
      tester.getCenter(find.text('100%')).dx,
      allOf(
        greaterThan(
          tester
              .getCenter(
                find.byKey(const ValueKey('reader-text-scale-decrease')),
              )
              .dx,
        ),
        lessThan(
          tester
              .getCenter(
                find.byKey(const ValueKey('reader-text-scale-increase')),
              )
              .dx,
        ),
      ),
    );
  });

  for (final scale in [1.5, 3.0]) {
    testWidgets('text size glyphs follow text scale $scale inside 48dp', (
      tester,
    ) async {
      await tester.openAppearanceSheet(
        cubit,
        textScaler: TextScaler.linear(scale),
      );
      RenderParagraph glyph(String key) => tester.renderObject(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.text('A'),
        ),
      );
      final small = glyph('reader-text-scale-decrease');
      final large = glyph('reader-text-scale-increase');
      // Scales with text until the large "A" fills its 48dp target.
      final effective = math.min(scale, AppSizes.buttonHeight / 22);
      expect(small.textScaler.scale(14), closeTo(14 * effective, 0.01));
      expect(large.textScaler.scale(22), closeTo(22 * effective, 0.01));
      expect(large.size.height, lessThanOrEqualTo(AppSizes.buttonHeight));
      for (final key in [
        'reader-text-scale-decrease',
        'reader-text-scale-increase',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))),
          const Size.square(AppSizes.buttonHeight),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('text size steps keep the cubit limits', (tester) async {
    await preferencesService.update(
      (prefs) =>
          prefs.copyWith(readerTextScale: ReaderAppearanceCubit.maxTextScale),
    );
    await tester.pump();
    await tester.openAppearanceSheet(cubit);
    final colors = tester.element(find.byType(BottomSheet)).colors;
    InkWell step(String key) => tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(InkWell),
      ),
    );

    expect(step('reader-text-scale-increase').onTap, isNull);
    expect(step('reader-text-scale-decrease').onTap, isNotNull);
    expect(
      _textSizeGlyph(tester, 'reader-text-scale-increase').style?.color,
      colors.onSurface.withValues(alpha: .38),
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byKey(const ValueKey('reader-text-scale-increase')),
          matching: find.text('A'),
        ),
      ),
      isSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();

    await tester.tap(find.byKey(const ValueKey('reader-text-scale-increase')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      cubit.state.effectiveAppearance.textScale,
      ReaderAppearanceCubit.maxTextScale,
    );
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);

    await tester.runAsync(
      () => preferencesService.update(
        (prefs) =>
            prefs.copyWith(readerTextScale: ReaderAppearanceCubit.minTextScale),
      ),
    );
    await tester.pumpAndSettle();

    expect(step('reader-text-scale-decrease').onTap, isNull);
    expect(step('reader-text-scale-increase').onTap, isNotNull);
  });
}

Finder _fixedTabBodyHeightFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is SizedBox && widget.height == 360,
    description: 'fixed 360px appearance tab body',
  );
}

ReaderLineSpacingPreset _selectedLineSpacing(WidgetTester tester) => tester
    .widget<SegmentedButton<ReaderLineSpacingPreset>>(
      find.byType(SegmentedButton<ReaderLineSpacingPreset>),
    )
    .selected
    .single;

ReaderMarginPreset _selectedMargin(WidgetTester tester) => tester
    .widget<SegmentedButton<ReaderMarginPreset>>(
      find.byType(SegmentedButton<ReaderMarginPreset>),
    )
    .selected
    .single;

ReaderTextAlignment _selectedAlignment(WidgetTester tester) => tester
    .widget<AppChoiceControl<ReaderTextAlignment>>(
      find.byKey(const ValueKey('reader-text-alignment-control')),
    )
    .selected;

Text _textSizeGlyph(WidgetTester tester, String key) => tester.widget<Text>(
  find.descendant(of: find.byKey(ValueKey(key)), matching: find.text('A')),
);

Text _stepperValueText(WidgetTester tester, Key key) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(Text),
    ),
  );
}

extension on WidgetTester {
  Future<void> openFontStep() async {
    await tap(find.byKey(const ValueKey('reader-font-picker')).hitTestable());
    await pumpAndSettle();
  }

  Future<void> openAppearanceSheet(
    ReaderAppearanceCubit cubit, {
    bool showPageTurnControls = true,
    bool pdfControls = false,
    Locale locale = const Locale('en'),
    bool disableAnimations = false,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection? textDirection,
  }) async {
    await pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: textScaler,
          ),
          child: textDirection == null
              ? child!
              : Directionality(textDirection: textDirection, child: child!),
        ),
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showReaderAppearanceSheet(
                      context,
                      showPageTurnControls: showPageTurnControls,
                      pdfControls: pdfControls,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tap(find.text('Open'));
    await pumpAndSettle();
  }
}
