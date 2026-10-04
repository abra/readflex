import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/select_collection_scope_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      for (final cached in [false, true]) {
        testWidgets(
          'collection retry keeps sheet open: $locale / $size / cached=$cached',
          (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final states = StreamController<LibraryState>.broadcast();
            addTearDown(states.close);
            var retries = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light(),
                locale: locale,
                localizationsDelegates:
                    ReadflexLocalizations.localizationsDelegates,
                supportedLocales: ReadflexSupportedLocales.locales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Open'),
                      onPressed: () => showLibraryCollectionScopeSheet(
                        context: context,
                        state: LibraryState(
                          collectionsLoadFailed: true,
                          collectionScopes: cached
                              ? [LibraryCollectionScope.favourites()]
                              : [],
                        ),
                        states: states.stream,
                        onRetry: () {
                          retries++;
                          states.add(
                            LibraryState(
                              collectionScopes: [
                                LibraryCollectionScope.favourites(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            final strings = tester.element(find.byType(BottomSheet)).l10n;
            expect(
              find.text(strings.libraryLoadCollectionsFailed),
              findsOneWidget,
            );
            expect(find.text(strings.libraryNoCollectionsYet), findsNothing);
            await tester.tap(find.text(strings.commonRetry));
            await tester.pumpAndSettle();
            expect(retries, 1);
            expect(
              find.text(strings.libraryLoadCollectionsFailed),
              findsNothing,
            );
            expect(find.text(strings.libraryFavourites), findsOneWidget);
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
