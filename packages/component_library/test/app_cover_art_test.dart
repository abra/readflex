import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isArticle in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('cover text stays inside its frame: $isArticle/$scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: AppCoverArt(
                    title:
                        'A long title about portable batteries and charging devices ' *
                        8,
                    author: 'Author',
                    source: 'A publication with a longer name',
                    height: 195,
                    width: 130,
                    isArticle: isArticle,
                    topAlignText: true,
                    bottomReserve: 16,
                  ),
                ),
              ),
            ),
          ),
        );
        final cover = tester.getRect(find.byType(AppCoverArt));
        final texts = find.descendant(
          of: find.byType(AppCoverArt),
          matching: find.byType(Text),
        );
        for (final text in texts.evaluate()) {
          final bounds = tester.getRect(find.byWidget(text.widget));
          expect(bounds.top, greaterThanOrEqualTo(cover.top));
          expect(bounds.bottom, lessThanOrEqualTo(cover.bottom - 16));
        }
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('cover text keeps explicit fonts (article=$isArticle)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: AppCoverArt(
                title: 'Portable power',
                author: 'Readflex Tests',
                source: 'Readflex News',
                height: 300,
                width: 200,
                isArticle: isArticle,
              ),
            ),
          ),
        ),
      );
      final text = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(AppCoverArt),
          matching: find.byType(Text),
        ),
      );
      expect(text, hasLength(2));
      for (final widget in text) {
        final style = widget.style!;
        // Covers intentionally do not inherit route/Hero text styles.
        expect(style.inherit, isFalse);
        expect(style.fontFamily, AppTypography.fontFamilySans);
        expect(style.fontFamilyFallback, AppTypography.fontFamilyFallback);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
