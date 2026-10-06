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
}
