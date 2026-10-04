import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
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
          final sheet = tester.getRect(find.byType(ActionBottomSheetLayout));
          expect(bounds.left - sheet.left, 24);
          expect(sheet.right - bounds.right, 24);
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
}
