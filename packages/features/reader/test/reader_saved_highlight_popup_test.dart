import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  testWidgets('tapping the page dismisses the popup without reaching it', (
    tester,
  ) async {
    var pageTaps = 0;
    var dismissed = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: Stack(
            children: [
              // Stands in for the WebView page: a page tap would toggle
              // chrome or turn the page.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => pageTaps++,
                ),
              ),
              Positioned.fill(
                child: ReaderSavedHighlightPopup(
                  position: const ReaderSelectionPosition(
                    left: 40,
                    top: 300,
                    right: 200,
                    bottom: 320,
                  ),
                  selectedColor: HighlightColor.yellow,
                  readerTheme: ReaderThemePreset.paper.data,
                  panelColor: Colors.white,
                  foregroundColor: Colors.black,
                  destructiveColor: Colors.red,
                  dividerColor: Colors.grey,
                  onDismiss: () => dismissed++,
                  onColorChanged: (_) {},
                  onDelete: () => deleted++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final popup = tester.getRect(find.byType(ReaderHighlightControls));
    // A page spot well away from the popup surface.
    final outside = Offset(popup.center.dx, popup.top - 200);
    expect(popup.contains(outside), isFalse);
    await tester.tapAt(outside);
    await tester.pump();
    expect(dismissed, 1);
    expect(pageTaps, 0);

    await tester.tap(find.byTooltip(l10n.readerRemoveHighlight));
    await tester.pump();
    expect(deleted, 1);
    expect(dismissed, 1);
    expect(pageTaps, 0);
  });
}
