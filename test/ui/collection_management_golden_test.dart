import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('collection management ${profile.name}', (tester) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final collection = await tester.runAsync(() async {
        final books = await app.bookRepository.getBooks();
        await app.collectionRepository.addSourcesToFavourites(
          sourceIds: books.map((book) => book.id),
        );
        return app.collectionRepository.createCollectionWithSources(
          name: 'Weekend reading',
          sourceIds: books.map((book) => book.id),
        );
      });
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app.preferencesService.update(
        (p) => p.copyWith(
          locale: profile.locale,
          themeMode: profile.brightness == Brightness.light
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widget),
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'library',
      );
      await tapUi(tester, find.byIcon(AppIcons.collection));
      await expectUiGolden(tester, profile, 'collection-picker');
      final pickerStrings = ReadflexLocalizations.of(
        tester.element(find.byType(BottomSheet)),
      )!;
      await tapUi(
        tester,
        find.byKey(
          const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
        ),
      );
      await expectUiGolden(tester, profile, 'library-favourites-badge');
      await tapUi(tester, find.byTooltip(pickerStrings.libraryFavourites));
      await expectUiGolden(tester, profile, 'collection-picker-selected');
      await tapUi(tester, find.byTooltip(pickerStrings.commonClose));
      await tapUi(
        tester,
        find.byTooltip(pickerStrings.libraryClearCollectionFilter),
      );
      await tapUi(tester, find.byIcon(AppIcons.collection));
      await tapUi(
        tester,
        find.byKey(ValueKey('collectionScopeManage-manual-${collection!.id}')),
      );
      await expectUiGolden(tester, profile, 'collection-manage');
      final sheet = find.byKey(const ValueKey('manageCollectionContent'));
      final strings = ReadflexLocalizations.of(tester.element(sheet))!;
      final remove = find.byKey(
        ValueKey('collectionSourceRemove-${app.book!.id}'),
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      final removeBounds = tester.getRect(remove);
      await tapUi(tester, remove);
      final undo = find.byKey(ValueKey('collectionSourceUndo-${app.book!.id}'));
      expect(tester.getRect(undo), removeBounds);
      expect(find.text(strings.commonUndo), findsNothing);
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
      await expectUiGolden(tester, profile, 'collection-undo');
      await tapUi(tester, undo);
      expect(find.byIcon(AppIcons.undo), findsNothing);
      // One full-width Save; leaving is the header's job.
      final save = tester.getRect(
        find.widgetWithText(FilledButton, strings.commonSave),
      );
      // Wide profiles cap the sheet content; the header spans that content.
      expect(
        save.width,
        tester.getRect(find.byType(BottomSheetHeader)).width -
            2 * AppSpacing.xl,
      );
      expect(find.byType(OutlinedButton), findsNothing);
      final field = find.descendant(
        of: sheet,
        matching: find.byType(TextField),
      );
      final delete = find.text(strings.libraryDeleteCollectionButton);
      await tester.ensureVisible(delete);
      await tapUi(tester, delete);
      await expectUiGolden(tester, profile, 'collection-delete');
      await tapUi(tester, find.byTooltip(strings.commonBack));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Changed');
      await tapUi(tester, find.byTooltip(strings.commonClose));
      await expectUiGolden(tester, profile, 'collection-discard');
      await tapUi(tester, find.text(strings.commonKeepEditing));
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
