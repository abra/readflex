import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isArticle in [false, true]) {
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
