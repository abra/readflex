import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/select_collection_scope_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  for (final dark in [false, true]) {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets(
        'collection selected state and symmetric fill ($dark/$locale)',
        (tester) async {
          final scope = LibraryCollectionScope.favourites(sourceIds: ['book']);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: locale,
              localizationsDelegates:
                  ReadflexLocalizations.localizationsDelegates,
              supportedLocales: ReadflexSupportedLocales.locales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showLibraryCollectionScopeSheet(
                      context: context,
                      state: LibraryState(
                        collectionScopes: [scope],
                        selectedCollectionScope: scope,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final row = find.byKey(
            const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
          );
          expect(
            tester
                .getSemantics(row)
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
          );
          expect(find.byIcon(AppIcons.check), findsOneWidget);
          final fill = find.byKey(
            const ValueKey(
              'collectionScopeSelection-favourites-readflex:favourites',
            ),
          );
          final bounds = tester.getRect(fill);
          // On wide viewports the route includes space outside its sheet surface.
          // The pill bleeds 8dp into both 24dp gutters.
          final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
          expect(bounds.left - sheet.left, AppSpacing.xl - AppSpacing.sm);
          expect(sheet.right - bounds.right, AppSpacing.xl - AppSpacing.sm);
          final colors = Theme.of(tester.element(fill)).colorScheme;
          expect(
            (tester.widget<Ink>(fill).decoration as BoxDecoration).color,
            colors.selectedControlBackground,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('counts share one column with and without a row menu '
        '($locale)', (tester) async {
      final favourites = LibraryCollectionScope.favourites(sourceIds: ['a']);
      const author = LibraryCollectionScope.smart(
        type: LibraryCollectionScopeType.author,
        id: 'author:readflex',
        label: 'Readflex Tests',
        sourceCount: 7,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLibraryCollectionScopeSheet(
                  context: context,
                  state: LibraryState(collectionScopes: [favourites, author]),
                  manageBuilder: (_, _, _, _) => const SizedBox(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final managed = tester.getRect(find.text('1'));
      final plain = tester.getRect(find.text('7'));
      // Same trailing edge whether or not the row has a ⋮ menu.
      if (locale.languageCode == 'ar') {
        expect(plain.left, closeTo(managed.left, 1));
      } else {
        expect(plain.right, closeTo(managed.right, 1));
      }
    });
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('picker rows, section titles and menu glyph sit on the 24dp '
        'gutter ($locale)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final favourites = LibraryCollectionScope.favourites(sourceIds: ['a']);
      const author = LibraryCollectionScope.smart(
        type: LibraryCollectionScopeType.author,
        id: 'author:readflex',
        label: 'Readflex Tests',
        sourceCount: 7,
      );
      final manual = LibraryCollectionScope.manual(
        collection: LibraryCollection(
          id: 'reading',
          name: 'Reading',
          sourceCount: 2,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        sourceIds: const {'a', 'b'},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLibraryCollectionScopeSheet(
                  context: context,
                  state: LibraryState(
                    collectionScopes: [favourites, manual, author],
                    selectedCollectionScope: manual,
                  ),
                  manageBuilder: (_, _, _, _) => const SizedBox(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final rtl = locale.languageCode == 'ar';
      final sheet = tester.getRect(find.byType(BottomSheet));
      double start(Rect r) => rtl ? sheet.right - r.right : r.left - sheet.left;
      double end(Rect r) => rtl ? r.left - sheet.left : sheet.right - r.right;
      final strings = tester.element(find.byType(BottomSheet)).l10n;

      final search = tester.getRect(find.byType(SearchField));
      final title = tester.getRect(find.text(strings.libraryManualCollections));
      final favouriteIcon = tester.getRect(
        find.byIcon(AppIcons.collectionFavourites),
      );
      final authorIcon = tester.getRect(find.byIcon(AppIcons.author));
      final menu = find.byKey(
        const ValueKey('collectionScopeManage-manual-reading'),
      );
      final menuGlyph = tester.getRect(
        find.descendant(of: menu, matching: find.byIcon(AppIcons.moreVertical)),
      );
      final pill = tester.getRect(
        find.byKey(const ValueKey('collectionScopeSelection-manual-reading')),
      );
      expect(start(search), AppSpacing.xl);
      expect(end(search), AppSpacing.xl);
      expect(start(title), closeTo(AppSpacing.xl, .01));
      expect(start(favouriteIcon), closeTo(AppSpacing.xl, .01));
      expect(start(authorIcon), closeTo(AppSpacing.xl, .01));
      expect(end(menuGlyph), closeTo(AppSpacing.xl, .01));
      expect(tester.getSize(menu), const Size.square(48));
      expect(start(pill), AppSpacing.xl - AppSpacing.sm);
      expect(end(pill), AppSpacing.xl - AppSpacing.sm);
      // Counts end 12dp before the 48dp slot whose glyph is centered.
      final managedCount = tester.getRect(find.text('2'));
      final plainCount = tester.getRect(find.text('7'));
      expect(
        end(managedCount),
        closeTo(
          AppSpacing.xl +
              AppIconSize.sm +
              AppSizes.iconActionOutset +
              AppSpacing.md,
          .01,
        ),
      );
      expect(end(plainCount), closeTo(end(managedCount), .01));

      // Menu glyph colour follows the row's selection.
      final colors = Theme.of(tester.element(menu)).colorScheme;
      expect(
        tester.widget<AppPlainIconButton>(menu).color,
        colors.selectedControlForeground,
      );
      expect(
        tester
            .widget<AppPlainIconButton>(
              find.byKey(
                const ValueKey(
                  'collectionScopeManage-favourites-readflex:favourites',
                ),
              ),
            )
            .color,
        colors.onSurfaceVariant,
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('Library row', () {
    final favourites = LibraryCollectionScope.favourites(sourceIds: ['a']);
    final manual = LibraryCollectionScope.manual(
      collection: LibraryCollection(
        id: 'reading',
        name: 'Reading',
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      sourceIds: const {'b'},
    );
    final sources = [
      for (final id in ['a', 'b', 'c'])
        LibrarySource.fromBook(
          Book(
            id: id,
            title: 'Book $id',
            filePath: '/$id.epub',
            format: BookFormat.epub,
            addedAt: DateTime(2026),
          ),
        ),
    ];
    final libraryRow = find.byKey(const ValueKey('collectionScopeRow-library'));
    final libraryPill = find.byKey(
      const ValueKey('collectionScopeSelection-library'),
    );

    Future<List<LibraryCollectionScopeSheetResult?>> open(
      WidgetTester tester, {
      LibraryCollectionScope? selected,
      Locale locale = const Locale('en'),
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final results = <LibraryCollectionScopeSheetResult?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showLibraryCollectionScopeSheet(
                    context: context,
                    state: LibraryState(
                      sources: sources,
                      collectionScopes: [favourites, manual],
                      selectedCollectionScope: selected,
                    ),
                    manageBuilder: (_, _, _, _) => const SizedBox(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return results;
    }

    bool isSelected(WidgetTester tester, Finder row) =>
        tester
            .getSemantics(row)
            .getSemanticsData()
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;

    testWidgets('follows Favourites with the library icon and total count', (
      tester,
    ) async {
      await open(tester, selected: manual);
      final strings = tester.element(find.byType(BottomSheet)).l10n;
      expect(
        find.descendant(
          of: libraryRow,
          matching: find.text(strings.libraryTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: libraryRow, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: libraryRow,
          matching: find.byIcon(AppIcons.library),
        ),
        findsOneWidget,
      );
      final favouritesRow = find.byKey(
        const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
      );
      // Favourites stays first, under the search field.
      expect(
        tester.getRect(favouritesRow).bottom,
        lessThanOrEqualTo(tester.getRect(libraryRow).top),
      );
      expect(tester.getSize(libraryRow).height, 48);
      // No manage menu; its 48dp slot is kept so counts stay aligned.
      expect(
        find.byKey(const ValueKey('collectionScopeManage-library')),
        findsNothing,
      );
      final libraryCount = tester.getRect(
        find.descendant(of: libraryRow, matching: find.text('3')),
      );
      final favouritesCount = tester.getRect(
        find.descendant(of: favouritesRow, matching: find.text('1')),
      );
      expect(libraryCount.right, closeTo(favouritesCount.right, .01));
    });

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('is selected without a scope, like other rows ($locale)', (
        tester,
      ) async {
        await open(tester, locale: locale);
        final rtl = locale.languageCode == 'ar';
        expect(isSelected(tester, libraryRow), isTrue);
        expect(
          find.descendant(
            of: libraryRow,
            matching: find.byIcon(AppIcons.check),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(AppIcons.check), findsOneWidget);
        final colors = Theme.of(tester.element(libraryPill)).colorScheme;
        expect(
          (tester.widget<Ink>(libraryPill).decoration as BoxDecoration).color,
          colors.selectedControlBackground,
        );
        final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
        final pill = tester.getRect(libraryPill);
        expect(
          rtl ? sheet.right - pill.right : pill.left - sheet.left,
          AppSpacing.xl - AppSpacing.sm,
        );
        final check = tester.getRect(
          find.descendant(
            of: libraryRow,
            matching: find.byIcon(AppIcons.check),
          ),
        );
        expect(
          rtl ? sheet.right - check.right : check.left - sheet.left,
          closeTo(AppSpacing.xl, .01),
        );
        final label = tester.widget<Text>(
          find.descendant(
            of: libraryRow,
            matching: find.text(
              tester.element(libraryRow).l10n.libraryTitle,
            ),
          ),
        );
        expect(label.style!.color, colors.selectedControlForeground);
      });
    }

    testWidgets('is not selected while a collection is', (tester) async {
      await open(tester, selected: manual);
      expect(isSelected(tester, libraryRow), isFalse);
      expect(libraryPill, findsNothing);
      expect(
        isSelected(
          tester,
          find.byKey(const ValueKey('collectionScopeRow-manual-reading')),
        ),
        isTrue,
      );
      expect(
        find.descendant(of: libraryRow, matching: find.byIcon(AppIcons.check)),
        findsNothing,
      );
    });

    testWidgets('tapping it clears the scope and closes the sheet', (
      tester,
    ) async {
      final results = await open(tester, selected: manual);
      await tester.tap(libraryRow);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(results.single, isA<LibraryCollectionScopeCleared>());
    });

    testWidgets('other rows still select their scope', (tester) async {
      final results = await open(tester);
      await tester.tap(
        find.byKey(const ValueKey('collectionScopeRow-manual-reading')),
      );
      await tester.pumpAndSettle();
      final result = results.single;
      expect(result, isA<LibraryCollectionScopeSelected>());
      expect((result! as LibraryCollectionScopeSelected).scope, manual);
    });

    testWidgets('the ⋮ manage action still works beside it', (tester) async {
      await open(tester);
      expect(
        find.byKey(const ValueKey('collectionScopeManage-manual-reading')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('collectionScopeManage-manual-reading')),
      );
      await tester.pumpAndSettle();
      // The manage step replaces the selector in the same sheet.
      expect(libraryRow.hitTestable(), findsNothing);
    });

    testWidgets('follows the collection search', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'read');
      await tester.pump();
      expect(libraryRow, findsNothing);
      expect(
        find.byKey(const ValueKey('collectionScopeRow-manual-reading')),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'libr');
      await tester.pump();
      expect(libraryRow, findsOneWidget);
      expect(
        find.byKey(const ValueKey('collectionScopeRow-manual-reading')),
        findsNothing,
      );
    });
  });
}
