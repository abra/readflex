import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('selected search uses paired colors (${theme.brightness})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: ReaderSearchResultTile(
              result: const ReaderSearchResult(
                cfi: 'selected',
                chapterTitle: 'Chapter',
                excerpt: ReaderSearchExcerpt(
                  pre: 'Before ',
                  match: 'word',
                  post: ' after',
                ),
              ),
              selected: true,
              pageProgressionRtl: false,
              onTap: () {},
            ),
          ),
        ),
      );
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      final colors = theme.colorScheme;
      expect(tile.selectedTileColor, colors.selectedControlBackground);
      final excerpt = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'Before word after',
        ),
      );
      expect(excerpt.text.style?.color, colors.selectedControlForeground);
      expect(
        (excerpt.text as TextSpan).children![1].style?.color,
        colors.selectedControlForeground,
      );
      final ink = colors.selectedControlForeground.computeLuminance() + .05;
      final fill =
          Color.alphaBlend(
            colors.selectedControlBackground,
            colors.surface,
          ).computeLuminance() +
          .05;
      // Either side may be the lighter one: dark mode tints a dark surface.
      expect(
        fill > ink ? fill / ink : ink / fill,
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  for (final rtl in [false, true]) {
    testWidgets(
      'search excerpt respects text scaling and direction (rtl=$rtl)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            supportedLocales: ReadflexSupportedLocales.locales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ReaderSearchResultTile(
                result: const ReaderSearchResult(
                  cfi: 'result-1',
                  chapterTitle: 'Chapter',
                  excerpt: ReaderSearchExcerpt(
                    pre: 'Some ',
                    match: 'selected',
                    post: ' text for reading',
                  ),
                ),
                pageProgressionRtl: rtl,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        final excerpt = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Some selected'),
        );
        final text = tester.widget<RichText>(excerpt);
        expect(text.textScaler.scale(16), 32);
        expect(text.textDirection, rtl ? TextDirection.rtl : TextDirection.ltr);
        expect(text.maxLines, 3);
        await tester.tap(find.byType(ListTile));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
