import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_selection_bar.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'golden_support.dart';

/// Bulk action labels with the app's fonts in every locale. The library
/// package checks the layout with the test font, which is about twice as wide
/// as Geist and so cannot tell whether a label fits.
void main() {
  setUpAll(loadUiFonts);

  // The smallest wide window: Split View halves and phones stay narrow.
  const smallestWide = Size(840, 480);

  Future<void> pumpBar(
    WidgetTester tester, {
    required Size window,
    required double ratio,
    required double textScale,
    required Locale locale,
  }) async {
    tester.view
      ..physicalSize = window * ratio
      ..devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final cubit = LibrarySelectionCubit()
      ..toggle('a')
      ..toggle('b');
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            bottomNavigationBar: LibrarySelectionBar(
              onAddToCollection: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
  }

  RenderParagraph paragraph(WidgetTester tester, Finder text) => tester
      .renderObject(find.descendant(of: text, matching: find.byType(RichText)));

  // Fallback fonts (Arabic, Devanagari, CJK) give boxes on one line
  // different tops, so a line is a run of vertically overlapping boxes.
  int lines(RenderParagraph paragraph) {
    final length = paragraph.text.toPlainText().length;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
    )..sort((a, b) => a.top.compareTo(b.top));
    var lines = 0;
    var bottom = double.negativeInfinity;
    for (final box in boxes) {
      if (box.top >= bottom - 1) {
        lines++;
        bottom = box.bottom;
      } else if (box.bottom > bottom) {
        bottom = box.bottom;
      }
    }
    return lines;
  }

  for (final locale in ReadflexSupportedLocales.locales) {
    for (final (window, ratio, textScale) in const [
      (smallestWide, 1.0, 1.0),
      (smallestWide, 1.0, 2.0),
      (Size(1032, 1376), 2.0, 1.0),
      (Size(390, 844), 1.0, 1.0),
      (Size(320, 568), 1.0, 1.0),
      (Size(320, 568), 2.0, 1.0),
      (Size(320, 568), 1.0, 2.0),
    ]) {
      testWidgets('bulk action labels fit '
          '(${window.width.round()}@${ratio.round()}x, text ${textScale}x, '
          '${locale.toLanguageTag()})', (tester) async {
        await pumpBar(
          tester,
          window: window,
          ratio: ratio,
          textScale: textScale,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
        final l10n = tester.element(find.byType(LibrarySelectionBar)).l10n;
        final label = paragraph(
          tester,
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(AppButtonLabel),
          ),
        );
        final count = paragraph(
          tester,
          find.text(l10n.librarySelectedCount(2)),
        );
        // Large text and narrow phones may wrap the command onto its second
        // line; nothing ends in an ellipsis.
        expect(label.didExceedMaxLines, isFalse);
        if (textScale == 1) expect(lines(count), 1);
        if (window.width < smallestWide.width) return;

        final close = find.widgetWithIcon(AppPlainIconButton, AppIcons.close);
        expect(
          tester.getRect(find.byType(FilledButton)).center.dy,
          closeTo(tester.getRect(close).center.dy, .5),
          reason: 'one row',
        );
        if (textScale == 1) expect(lines(label), 1);
      });
    }
  }
}
