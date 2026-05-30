import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_image_page_progress_overlay.dart';

void main() {
  testWidgets(
    'image page progress overlay auto-hides and resets on page change',
    (tester) async {
      await tester.pumpOverlay(currentPage: null, totalPages: null);

      expect(find.byKey(_overlayOpacityKey), findsNothing);

      await tester.pumpOverlay(currentPage: 0, totalPages: 25);

      expect(find.text('1 / 25'), findsOneWidget);
      expect(tester.overlayOpacity.opacity, 1);

      await tester.pump(const Duration(milliseconds: 2999));
      expect(tester.overlayOpacity.opacity, 1);

      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.overlayOpacity.opacity, 0);

      await tester.pumpOverlay(currentPage: 2, totalPages: 25);

      expect(find.text('3 / 25'), findsOneWidget);
      expect(tester.overlayOpacity.opacity, 1);
    },
  );

  testWidgets(
    'image page progress overlay hides while reader chrome is visible',
    (tester) async {
      await tester.pumpOverlay(currentPage: 0, totalPages: 25);

      expect(tester.overlayOpacity.opacity, 1);

      await tester.pumpOverlay(
        currentPage: 0,
        totalPages: 25,
        chromeVisible: true,
      );

      expect(tester.overlayOpacity.opacity, 0);
    },
  );
}

const _overlayOpacityKey = ValueKey('readerImagePageProgressOverlayOpacity');

extension on WidgetTester {
  Future<void> pumpOverlay({
    required int? currentPage,
    required int? totalPages,
    BookFormat format = BookFormat.cbz,
    bool chromeVisible = false,
    bool selectionActionsVisible = false,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: [
              ReaderImagePageProgressOverlay(
                format: format,
                chromeVisible: chromeVisible,
                selectionActionsVisible: selectionActionsVisible,
                currentPage: currentPage,
                totalPages: totalPages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  AnimatedOpacity get overlayOpacity {
    return widget<AnimatedOpacity>(find.byKey(_overlayOpacityKey));
  }
}
