import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';
import 'package:library_feature/src/add_to_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  Future<AddToCollectionCubit> open(
    WidgetTester tester,
    FakeCollectionRepository repository, {
    double inset = 0,
    double scale = 1,
    int count = 7,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository.seedCollections(
      List.generate(
        count,
        (i) => LibraryCollection(
          id: '$i',
          name: 'Collection $i',
          sourceCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    final cubit = AddToCollectionCubit(collectionRepository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.only(bottom: inset),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddToCollectionSheet(
                context: context,
                cubit: cubit,
                sourceIds: {'book'},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return cubit;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('collection actions stay above keyboard at $scale', (
      tester,
    ) async {
      await open(tester, FakeCollectionRepository(), inset: 320, scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Create').hitTestable(), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(find.text('Create')).dy, lessThan(844 - 320));
      await tester.scrollUntilVisible(
        find.byType(TextField),
        150,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('load failure has retry, not an empty creation form', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()..shouldThrow = true;
    await open(tester, repository);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    repository.shouldThrow = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('long collections remain lazy', (tester) async {
    await open(tester, FakeCollectionRepository(), count: 1000);
    expect(find.textContaining('Collection ').evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });
}
