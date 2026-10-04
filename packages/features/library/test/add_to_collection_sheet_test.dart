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
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create and add').hitTestable(), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Create and add')).dy,
        lessThan(844 - 320),
      );
      await tester.ensureVisible(find.byType(TextField));
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
    expect(find.byType(TextField), findsNothing);
    expect(find.text('New collection'), findsOneWidget);
  });

  testWidgets('existing membership is explicit and does not add again', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()
      ..seedCollectionSourceIds({
        '0': {'book'},
      });
    await open(tester, repository);
    final row = find
        .ancestor(of: find.text('Collection 0'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(row).onTap, isNull);
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIcons.check)),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.add), findsNothing);
    expect(find.text('Collection 1').hitTestable(), findsOneWidget);
  });

  for (final label in ['Favourites', 'Collection 0']) {
    testWidgets('destination rows omit plus and stay tappable: $label', (
      tester,
    ) async {
      final repository = FakeCollectionRepository();
      await open(tester, repository, count: 2);
      expect(find.byIcon(AppIcons.add), findsNothing);
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      final bounds = tester.getRect(row);
      await tester.tapAt(Offset(bounds.right - 2, bounds.center.dy));
      await tester.pumpAndSettle();
      expect(
        label == 'Favourites'
            ? repository.favouriteSourceIds
            : repository.addedSourceIdsByCollection['0'],
        {'book'},
      );
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets('Back returns to destinations while Close leaves the flow', (
    tester,
  ) async {
    await open(tester, FakeCollectionRepository());
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection 0'), findsOneWidget);
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Draft',
    );
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('long collections remain lazy', (tester) async {
    await open(tester, FakeCollectionRepository(), count: 1000);
    expect(find.textContaining('Collection ').evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creation is a stable separate step and retains its draft', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    await open(tester, repository, count: 3);
    expect(find.byType(TextField), findsNothing);
    final bounds = tester.getRect(find.byType(BottomSheet));
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create and add'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Research');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Research',
    );
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });

  testWidgets('existing collection still adds with one tap', (tester) async {
    final repository = FakeCollectionRepository();
    await open(tester, repository);
    await tester.tap(find.text('Collection 0'));
    await tester.pumpAndSettle();
    expect(repository.addedSourceIdsByCollection['0'], {'book'});
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('creation failure retains draft and height; retry creates once', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    await open(tester, repository, count: 2);
    final bounds = tester.getRect(find.byType(BottomSheet));
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Research');
    await tester.pump();
    repository.shouldThrow = true;
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Research',
    );
    final context = tester.element(find.byType(TextField));
    expect(
      find.text(context.l10n.libraryCreateCollectionFailed),
      findsOneWidget,
    );
    repository.shouldThrow = false;
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });
}
