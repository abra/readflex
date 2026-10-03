import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/manage_collection_cubit.dart';
import 'package:library_feature/src/manage_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  late FakeCollectionRepository repository;

  Future<void> open(WidgetTester tester) async {
    repository = FakeCollectionRepository();
    final collection = LibraryCollection(
      id: 'collection',
      name: 'Reading',
      sourceCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    repository.seedCollections([collection]);
    final cubit = ManageCollectionCubit(collectionRepository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showManageCollectionSheet(
                context: context,
                cubit: cubit,
                scope: LibraryCollectionScope.manual(
                  collection: collection,
                  sourceIds: const [],
                ),
                sources: const [],
                onCollectionChanged: () {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final method in ['back', 'systemBack', 'cancel']) {
    testWidgets('delete $method returns to the unchanged draft', (
      tester,
    ) async {
      await open(tester);
      expect(find.byTooltip('Back'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Draft');
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);
      switch (method) {
        case 'back':
          await tester.tap(find.byTooltip('Back'));
        case 'systemBack':
          await tester.binding.handlePopRoute();
        case 'cancel':
          await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
      expect((await repository.getCollections()).single.name, 'Reading');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('close on delete dismisses the entire unedited flow', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Delete collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect((await repository.getCollections()).single.name, 'Reading');
  });

  testWidgets('close on delete guards changes and never silently discards', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.tap(find.text('Delete collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect((await repository.getCollections()).single.name, 'Reading');
    expect(tester.takeException(), isNull);
  });
}
