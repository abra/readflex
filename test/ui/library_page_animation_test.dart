import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:pagecraft/all_formats.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

void main() {
  testWidgets(
    'Library animation choice reaches the book through the real router',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final sourceId = app.book!.id;
      await app.preferencesService.setReaderAppearanceOverride(
        sourceId,
        const ReaderAppearanceOverride(fontId: 'ptSerif'),
      );
      await tester.pumpWidget(app.widget);

      final display = find.byKey(const ValueKey('libraryHeaderDisplayButton'));
      final pages = find.byType(TextPagesView);
      final tile = find.byKey(ValueKey('library-grid-$sourceId'));
      final continueReading = find.byKey(
        const ValueKey('libraryContinueReadingCard'),
      );
      for (final (choice, preference, animation) in [
        ('slide', ReaderPageAnimation.slide, PageTurnAnimation.slide),
        ('cover', ReaderPageAnimation.cover, PageTurnAnimation.cover),
      ]) {
        await tapUi(tester, display);
        final option = find.byKey(ValueKey('library-page-animation-$choice'));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tapUi(tester, option);
        expect(app.preferencesService.current.readerPageAnimation, preference);
        await tapUi(tester, find.byTooltip('Close').hitTestable());
        await tester.pumpAndSettle();

        await waitForUi(
          tester,
          () =>
              tile.hitTestable().evaluate().isNotEmpty ||
              continueReading.hitTestable().evaluate().isNotEmpty,
          description: 'saved book in Library',
        );
        await tapUi(
          tester,
          tile.hitTestable().evaluate().isNotEmpty ? tile : continueReading,
        );
        await waitForUi(
          tester,
          () =>
              pages.evaluate().isNotEmpty &&
              find.byType(TextColumnPage).evaluate().isNotEmpty,
          description: 'rendered FB2 book',
        );
        final view = tester.widget<TextPagesView>(pages);
        expect(view.pageTurnAnimation, animation);
        expect(view.controller.position, isNotNull);
        expect(
          app.preferencesService.effectiveReaderAppearanceFor(sourceId).fontId,
          'ptSerif',
          reason: 'a global animation change preserves the book font override',
        );
        GoRouter.of(tester.element(pages)).pop();
        await tester.pumpAndSettle();
        await waitForUi(
          tester,
          () => display.hitTestable().evaluate().isNotEmpty,
          description: 'Library after closing the book',
        );
        expect(pages, findsNothing);
        expect(tester.takeException(), isNull);
      }

      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await unmountUi(tester);
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}
