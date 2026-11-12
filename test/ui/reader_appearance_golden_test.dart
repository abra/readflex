import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';

import '../support/ui_test_app.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  late UiTestApp app;
  setUp(() async => app = await UiTestApp.create(withBook: false));
  tearDown(() => app.dispose());
  for (final (profile, surfaceSize, suffix) in [
    for (final profile in VisualProfile.values) (profile, null, ''),
    (VisualProfile.tabletRtl, VisualProfile.phone.size, '-phone-rtl'),
  ]) {
    testWidgets('appearance controls ${profile.name}$suffix', (tester) async {
      final cubit = ReaderAppearanceCubit(
        preferencesService: app.preferencesService,
        sourceId: 'appearance-fixture',
      );
      addTearDown(cubit.close);
      late BuildContext sheetContext;
      await pumpGoldenSurface(
        tester,
        profile,
        surfaceSize: surfaceSize,
        (_) => BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              sheetContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      showReaderAppearanceSheet(sheetContext);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reader-page-animation-control')),
        findsNothing,
      );
      for (final label in [
        sheetContext.l10n.readerAppearanceTitle,
        sheetContext.l10n.readerFontSize,
        sheetContext.l10n.readerLineSpacing,
      ]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(label))
              .didExceedMaxLines,
          isFalse,
          reason: '$label must stay readable',
        );
      }
      final value = find.descendant(
        of: find.byKey(const ValueKey('reader-text-scale-value')),
        matching: find.byType(Text),
      );
      expect(
        tester.renderObject<RenderParagraph>(value).didExceedMaxLines,
        isFalse,
        reason: 'Font percentage must not be truncated',
      );
      await expectUiGolden(tester, profile, 'reader-appearance$suffix');
      final pageTurn = find.text(sheetContext.l10n.readerPageTurnVerticalShort);
      // Short/large-text screens must make the last row reachable, not clip it.
      await tester.ensureVisible(pageTurn);
      await tester.pumpAndSettle();
      expect(pageTurn.hitTestable(), findsOneWidget);
      await expectUiGolden(
        tester,
        profile,
        'reader-appearance-scrolled$suffix',
      );
      final fontPicker = find.byKey(const ValueKey('reader-font-picker'));
      await tester.ensureVisible(fontPicker);
      await tester.pumpAndSettle();
      final sheetBounds = tester.getRect(find.byType(BottomSheet));
      await tester.tap(fontPicker);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(BottomSheet)), sheetBounds);
      await expectUiGolden(tester, profile, 'reader-font$suffix');
      final lastFont = find.byKey(const ValueKey('reader-font-geist'));
      await tester.ensureVisible(lastFont);
      await tester.pumpAndSettle();
      expect(lastFont.hitTestable(), findsOneWidget);
      await tester.tap(lastFont);
      await tester.pumpAndSettle();
      expect(cubit.state.effectiveAppearance.fontId, 'geist');
      await expectUiGolden(tester, profile, 'reader-font-scrolled$suffix');
      await tester.tap(
        find.byTooltip(sheetContext.l10n.commonBack).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(BottomSheet)), sheetBounds);
      expect(fontPicker.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, tags: ['golden']);

    testWidgets('PDF page controls ${profile.name}$suffix', (tester) async {
      final cubit = ReaderAppearanceCubit(
        preferencesService: app.preferencesService,
        sourceId: 'pdf-fixture',
      );
      addTearDown(cubit.close);
      late BuildContext sheetContext;
      await pumpGoldenSurface(
        tester,
        profile,
        surfaceSize: surfaceSize,
        (_) => BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              sheetContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      showReaderAppearanceSheet(sheetContext, pdfControls: true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reader-page-animation-control')),
        findsNothing,
      );
      final l10n = sheetContext.l10n;
      for (final (control, label) in [
        ('reader-pdf-margins-control', l10n.readerPdfMarginsWhole),
        ('reader-pdf-margins-control', l10n.readerPdfMarginsTrimmed),
        ('reader-pdf-page-colors-control', l10n.readerPdfPageColorsTheme),
        ('reader-pdf-page-colors-control', l10n.readerPdfPageColorsOriginal),
      ]) {
        final text = find.descendant(
          of: find.byKey(ValueKey(control)),
          matching: find.text(label),
        );
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: '$label must stay readable',
        );
      }
      await expectUiGolden(tester, profile, 'reader-appearance-pdf$suffix');
      final pageTurn = find.text(l10n.readerPageTurnVerticalShort);
      await tester.ensureVisible(pageTurn);
      await tester.pumpAndSettle();
      expect(pageTurn.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, tags: ['golden']);
  }
}
