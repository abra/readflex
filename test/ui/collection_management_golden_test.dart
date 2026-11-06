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
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCollectionsButton')),
      );
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
      // The title names the collection; the switcher reopens the picker
      // with Favourites selected.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('libraryHeaderTitle')),
          matching: find.text(pickerStrings.libraryFavourites),
        ),
        findsOneWidget,
      );
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCollectionsButton')),
      );
      await expectUiGolden(tester, profile, 'collection-picker-selected');
      await tapUi(tester, find.byTooltip(pickerStrings.commonClose));
      // The picker's Library row clears the collection scope.
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCollectionsButton')),
      );
      await tapUi(
        tester,
        find.byKey(const ValueKey('collectionScopeRow-library')),
      );
      // The header title and the bottom switcher both name the Library.
      for (final key in ['libraryHeaderTitle', 'libraryCollectionsButton']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text(pickerStrings.libraryTitle),
          ),
          findsOneWidget,
          reason: key,
        );
      }
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCollectionsButton')),
      );
      await tapUi(
        tester,
        find.byKey(ValueKey('collectionScopeManage-manual-${collection!.id}')),
      );
      final sheet = find.byKey(const ValueKey('manageCollectionContent'));
      final strings = ReadflexLocalizations.of(tester.element(sheet))!;
      final remove = find.byKey(
        ValueKey('collectionSourceRemove-${app.book!.id}'),
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'collection-manage');
      final row = find.byKey(ValueKey('collectionSource-${app.book!.id}'));
      final title = find.descendant(
        of: row,
        matching: find.text(ReadingFixture.bookTitle),
      );
      final sourceIcon = find.descendant(
        of: row,
        matching: find.byIcon(AppIcons.book),
      );
      final titleBounds = tester.getRect(title);
      final sourceCenter = tester.getCenter(sourceIcon).dy;
      expect(titleBounds.center.dy, closeTo(sourceCenter, .01));
      final removeBounds = tester.getRect(remove);
      await tapUi(tester, remove);
      final undo = find.byKey(ValueKey('collectionSourceUndo-${app.book!.id}'));
      final pending = find.descendant(
        of: row,
        matching: find.text(strings.libraryRemovalPending),
      );
      expect(tester.getRect(title).top, lessThan(titleBounds.top));
      expect(
        tester
            .getRect(title)
            .expandToInclude(tester.getRect(pending))
            .center
            .dy,
        closeTo(sourceCenter, .01),
      );
      expect(tester.getRect(undo), removeBounds);
      expect(find.text(strings.commonUndo), findsNothing);
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
      await expectUiGolden(tester, profile, 'collection-undo');
      await tapUi(tester, undo);
      expect(tester.getRect(title), rectMoreOrLessEquals(titleBounds));
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

  for (final scale in [1.0, 2.0]) {
    testWidgets('collection source alignment on an RTL phone at ${scale}x', (
      tester,
    ) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final collection = (await tester.runAsync(
        () => app.collectionRepository.createCollectionWithSources(
          name: 'Reading',
          sourceIds: [app.book!.id],
        ),
      ))!;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app.preferencesService.update(
        (p) =>
            p.copyWith(locale: const Locale('ar'), themeMode: ThemeMode.dark),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widget),
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'library',
      );
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCollectionsButton')),
      );
      await tapUi(
        tester,
        find.byKey(ValueKey('collectionScopeManage-manual-${collection.id}')),
      );
      final row = find.byKey(ValueKey('collectionSource-${app.book!.id}'));
      final remove = find.byKey(
        ValueKey('collectionSourceRemove-${app.book!.id}'),
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      final strings = tester.element(row).l10n;
      final title = find.descendant(
        of: row,
        matching: find.text(ReadingFixture.bookTitle),
      );
      final sourceIcon = find.descendant(
        of: row,
        matching: find.byIcon(AppIcons.book),
      );
      final save = find.widgetWithText(FilledButton, strings.commonSave);
      final titleBounds = tester.getRect(title);
      final rowBounds = tester.getRect(row);
      final saveBounds = tester.getRect(save);
      final actionBounds = tester.getRect(remove);
      final sourceCenter = tester.getCenter(sourceIcon).dy;
      final suffix = scale == 1 ? 'phone-rtl' : 'phone-rtl-large';
      expect(titleBounds.center.dy, closeTo(sourceCenter, .01));
      await expectUiGolden(
        tester,
        VisualProfile.dark,
        'collection-manage-$suffix',
      );

      await tapUi(tester, remove);
      final undo = find.byKey(ValueKey('collectionSourceUndo-${app.book!.id}'));
      final pending = find.descendant(
        of: row,
        matching: find.text(strings.libraryRemovalPending),
      );
      final removedRowBounds = tester.getRect(row);
      // A zero-item count can reflow the header at large text. Label motion
      // preserves the row's local geometry independently of that reflow.
      expect(
        tester.getRect(title).top - removedRowBounds.top,
        lessThan(titleBounds.top - rowBounds.top),
      );
      expect(
        tester
            .getRect(title)
            .expandToInclude(tester.getRect(pending))
            .center
            .dy,
        closeTo(tester.getCenter(sourceIcon).dy, .01),
      );
      expect(
        tester.getRect(undo).shift(-removedRowBounds.topLeft),
        rectMoreOrLessEquals(actionBounds.shift(-rowBounds.topLeft)),
      );
      expect(removedRowBounds.width, closeTo(rowBounds.width, .01));
      expect(removedRowBounds.height, closeTo(rowBounds.height, .01));
      expect(
        tester.getCenter(sourceIcon).dy - removedRowBounds.top,
        closeTo(sourceCenter - rowBounds.top, .01),
      );
      expect(tester.getRect(save), rectMoreOrLessEquals(saveBounds));
      await expectUiGolden(
        tester,
        VisualProfile.dark,
        'collection-undo-$suffix',
      );

      await tapUi(tester, undo);
      expect(tester.getRect(title), rectMoreOrLessEquals(titleBounds));
      expect(tester.getRect(remove), rectMoreOrLessEquals(actionBounds));
      expect(tester.getRect(save), rectMoreOrLessEquals(saveBounds));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
