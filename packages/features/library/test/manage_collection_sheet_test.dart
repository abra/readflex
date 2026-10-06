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

  Future<void> open(
    WidgetTester tester, {
    List<LibrarySource> sources = const [],
    bool favourites = false,
    Locale locale = const Locale('en'),
  }) async {
    repository = FakeCollectionRepository();
    final collection = LibraryCollection(
      id: 'collection',
      name: 'Reading',
      sourceCount: sources.length,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    repository.seedCollections([collection]);
    final sourceIds = sources.map((source) => source.id).toSet();
    final scope = favourites
        ? LibraryCollectionScope.favourites(sourceIds: sourceIds)
        : LibraryCollectionScope.manual(
            collection: collection,
            sourceIds: sourceIds,
          );
    repository.seedCollectionSourceIds({scope.id: sourceIds});
    final cubit = ManageCollectionCubit(collectionRepository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showManageCollectionSheet(
                context: context,
                cubit: cubit,
                scope: scope,
                sources: sources,
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

  for (final favourites in [false, true]) {
    testWidgets(
      'staged removal can be undone without moving rows ($favourites)',
      (tester) async {
        final sources = List.generate(
          3,
          (index) => LibrarySource.fromBook(
            Book(
              id: 'book-$index',
              title: 'Book $index',
              filePath: '/book.epub',
              format: BookFormat.epub,
              addedAt: DateTime(2026),
            ),
          ),
        );
        await open(tester, sources: sources, favourites: favourites);
        final row = find.byKey(const ValueKey('collectionSourceRemove-book-0'));
        final next = find.byKey(
          const ValueKey('collectionSourceRemove-book-1'),
        );
        final bounds = tester.getRect(row);
        final nextBounds = tester.getRect(next);
        await tester.tap(row);
        await tester.pumpAndSettle();
        final undo = find.byKey(const ValueKey('collectionSourceUndo-book-0'));
        expect(
          find.descendant(of: undo, matching: find.byIcon(AppIcons.undo)),
          findsOneWidget,
        );
        expect(tester.getRect(undo), bounds);
        expect(tester.getRect(next), nextBounds);
        expect(repository.addedSourceIdsByCollection.values.single, {
          'book-0',
          'book-1',
          'book-2',
        });
        await tester.tap(next);
        await tester.pumpAndSettle();
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(tester.getRect(row), bounds);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(repository.addedSourceIdsByCollection.values.single, {
          'book-0',
          'book-2',
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('restoring all removals leaves no dirty draft', (tester) async {
    final source = LibrarySource.fromBook(
      Book(
        id: 'book',
        title: 'Book',
        filePath: '/book.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    );
    await open(tester, sources: [source]);
    await tester.tap(find.byKey(const ValueKey('collectionSourceRemove-book')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collectionSourceUndo-book')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });

  testWidgets('failed Save keeps removed item available for Undo', (
    tester,
  ) async {
    final source = LibrarySource.fromBook(
      Book(
        id: 'book',
        title: 'Book',
        filePath: '/book.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
    );
    await open(tester, sources: [source]);
    await tester.tap(find.byKey(const ValueKey('collectionSourceRemove-book')));
    await tester.pumpAndSettle();
    repository.shouldThrow = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collectionSourceUndo-book')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collectionSourceRemove-book')),
      findsOneWidget,
    );
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });

  for (final favourites in [false, true]) {
    testWidgets('trash removes only membership after Save ($favourites)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sources = [
        LibrarySource.fromBook(
          Book(
            id: 'book',
            title: 'Book',
            filePath: '/book.epub',
            format: BookFormat.epub,
            addedAt: DateTime(2026),
          ),
        ),
        LibrarySource.fromArticle(
          Article(
            id: 'article',
            title: 'Article',
            url: 'https://example.com/article',
            contentPath: '/article.json',
            addedAt: DateTime(2026),
          ),
        ),
      ];
      await open(
        tester,
        sources: sources,
        favourites: favourites,
        locale: Locale(favourites ? 'ar' : 'en'),
      );
      final strings = ReadflexLocalizations.of(
        tester.element(find.byType(BottomSheet)),
      )!;
      expect(find.byIcon(AppIcons.close), findsOneWidget);
      expect(find.byTooltip(strings.commonClose), findsOneWidget);
      final closeIcon = tester.getRect(find.byIcon(AppIcons.close));
      final semantics = tester.ensureSemantics();
      try {
        for (final source in sources) {
          final remove = find.byKey(
            ValueKey('collectionSourceRemove-${source.id}'),
          );
          expect(
            find.descendant(of: remove, matching: find.byIcon(AppIcons.delete)),
            findsOneWidget,
          );
          expect(tester.getSize(remove).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
          final icon = tester.getRect(
            find.descendant(of: remove, matching: find.byIcon(AppIcons.delete)),
          );
          expect(icon.size, closeIcon.size);
          expect(icon.center.dx, closeIcon.center.dx);
          expect(
            tester
                .getRect(find.byType(BottomSheet))
                .contains(
                  tester.getRect(remove).bottomRight - const Offset(1, 1),
                ),
            isTrue,
          );
          expect(
            tester.getSemantics(remove),
            matchesSemantics(
              tooltip: strings.libraryRemoveFromCollection(source.title),
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
        }
      } finally {
        semantics.dispose();
      }
      final removeBounds = tester.getRect(
        find.byKey(const ValueKey('collectionSourceRemove-book')),
      );
      // The part of the target beyond the glyph must remain interactive.
      await tester.tapAt(
        Offset(
          favourites ? removeBounds.left + 1 : removeBounds.right - 1,
          removeBounds.center.dy,
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<AppPlainIconButton>(
              find.byKey(const ValueKey('collectionSourceRemove-article')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpAndSettle();
      expect(find.text('Book'), findsOneWidget);
      expect(find.text('Article'), findsOneWidget);
      expect(repository.addedSourceIdsByCollection.values.single, {
        'book',
        'article',
      });
      await tester.tap(find.text(strings.commonSave));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository.addedSourceIdsByCollection.values.single, {'article'});
      expect((await repository.getCollections()).single.name, 'Reading');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('staged removal has no animation ticks or eager source rows', (
    tester,
  ) async {
    final sources = List.generate(
      50,
      (i) => LibrarySource.fromBook(
        Book(
          id: '$i',
          title: 'Book $i',
          filePath: '/book.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
        ),
      ),
    );
    await open(tester, sources: sources);
    await tester.tap(find.byKey(const ValueKey('collectionSourceRemove-0')));
    await tester.pump();
    final field = tester.widget(find.byType(TextField));
    final row = tester.widget(find.text('Book 1'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      expect(identical(tester.widget(find.byType(TextField)), field), isTrue);
      expect(identical(tester.widget(find.text('Book 1')), row), isTrue);
    }
    await tester.pumpAndSettle();
    expect(find.text('Book 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collectionSourceUndo-0')),
      findsOneWidget,
    );
    expect(find.text('Book 49'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  void expectSafeDefault(
    WidgetTester tester, {
    required String safe,
    required String destructive,
  }) {
    final filled = find.widgetWithText(FilledButton, safe);
    final outlined = find.widgetWithText(OutlinedButton, destructive);
    expect(filled, findsOneWidget);
    expect(outlined, findsOneWidget);
    expect(find.widgetWithText(FilledButton, destructive), findsNothing);
    final colors = Theme.of(tester.element(outlined)).colorScheme;
    final style = tester.widget<OutlinedButton>(outlined).style!;
    expect(style.foregroundColor!.resolve({}), colors.error);
    expect(style.side!.resolve({})!.color, colors.error);
    expect(
      tester.getCenter(outlined).dx,
      lessThan(tester.getCenter(filled).dx),
    );
  }

  testWidgets('delete confirmation keeps Cancel filled and Delete outlined', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Delete collection'));
    await tester.pumpAndSettle();
    expect(find.text('Delete collection?'), findsOneWidget);
    expectSafeDefault(tester, safe: 'Cancel', destructive: 'Delete');

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Manage collection'), findsOneWidget);
    expect(await repository.getCollections(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('discard confirmation keeps editing filled, Discard outlined', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expectSafeDefault(tester, safe: 'Keep editing', destructive: 'Discard');

    await tester.tap(find.widgetWithText(FilledButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Renamed',
    );
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('empty collection uses one compact placeholder: $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      final empty = find.byType(EmptyState);
      expect(empty, findsOneWidget);
      expect(tester.widget<EmptyState>(empty).compact, isTrue);
      final message = find.text('No items in this collection');
      expect(message, findsOneWidget);
      final context = tester.element(message);
      expect(
        tester.widget<Text>(message).style!.color,
        context.colors.onSurfaceVariant,
      );
      expect(
        tester.widget<Text>(message).style!.fontSize,
        context.text.bodyMedium.fontSize,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scrim closes an unchanged sheet', (tester) async {
    await open(tester);
    await tester.pump();
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ManageCollectionSheet), findsNothing);
  });

  testWidgets('scrim and drag with a renamed draft ask to discard', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Renamed');
    // Guard changes publish after the frame.
    await tester.pump();
    await tester.pump();

    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ManageCollectionSheet), findsOneWidget);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.drag(find.text('Discard changes?'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(ManageCollectionSheet), findsOneWidget);
  });
}
