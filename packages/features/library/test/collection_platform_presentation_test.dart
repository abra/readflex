import 'dart:ui' show CheckedState;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';
import 'package:library_feature/src/add_to_collection_sheet.dart';
import 'package:material_ui/material_ui.dart' show CheckboxListTile;
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/fake_collection_repository.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('$platform collection destinations use native rows $locale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view
            ..physicalSize = const Size(320, 568)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final repository = FakeCollectionRepository()
            ..seedCollections([
              LibraryCollection(
                id: 'reading',
                name: 'A collection with a long name that wraps naturally',
                sourceCount: 1234,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ]);
          final cubit = AddToCollectionCubit(collectionRepository: repository);
          addTearDown(cubit.close);
          int? added;
          await tester.pumpWidget(
            PlatformTestApp(
              platform: platform,
              locale: locale,
              supportedLocales: ReadflexSupportedLocales.locales,
              localizationsDelegates: readflexLocalizationsDelegates,
              textScale: 2,
              home: Builder(
                builder: (context) => Center(
                  child: AppButton(
                    onPressed: () async {
                      added = await showAddToCollectionSheet(
                        context: context,
                        cubit: cubit,
                        sourceIds: const {'book'},
                        onCollectionCreated: () {},
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final row = find.byKey(
            const ValueKey('addToCollectionDestination-reading'),
          );
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: row,
              matching: find.byType(CupertinoListTile),
              matchRoot: true,
            ),
            platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byType(CheckboxListTile),
              matchRoot: true,
            ),
            platform == TargetPlatform.android ? findsOneWidget : findsNothing,
          );
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
          expect(
            tester
                .getSemantics(row)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
            CheckedState.isFalse,
          );
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(
            tester
                .getSemantics(row)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
            CheckedState.isTrue,
          );
          expect(cubit.state.selectedCollectionIds, {'reading'});
          expect(repository.addedSourceIdsByCollection, isEmpty);
          final submit = find.byKey(
            const ValueKey('addToCollectionsSubmitButton'),
          );
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(added, 1);
          expect(repository.addedSourceIdsByCollection['reading'], {'book'});
          expect(find.byType(AddToCollectionSheet), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
