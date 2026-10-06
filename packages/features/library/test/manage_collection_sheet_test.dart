import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/manage_collection_cubit.dart';
import 'package:library_feature/src/manage_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  late FakeCollectionRepository repository;

  // Real label metrics: the count row and the confirmation pair decide
  // whether to stack by measuring text, which the square test font distorts.
  setUpAll(() async {
    await (FontLoader('Geist')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Geist-Variable.ttf',
          ),
        ))
        .load();
  });

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

  for (final method in ['back', 'systemBack', 'keep']) {
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
        case 'keep':
          await tester.tap(find.text('Keep'));
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

  testWidgets('delete confirmation keeps "Keep" filled and Delete '
      'outlined; Keep closes only the confirmation', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'Draft');
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(find.text('Delete collection?'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expectSafeDefault(tester, safe: 'Keep', destructive: 'Delete');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(find.widgetWithText(FilledButton, 'Keep'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Delete collection?'), findsNothing);
      expect(find.text('Manage collection'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
      expect(await repository.getCollections(), hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  // Geist covers Latin and Cyrillic; other scripts fall back to the test font.
  for (final code in ['en', 'ru', 'de', 'fr', 'es', 'pt']) {
    testWidgets('delete confirmation keeps Keep and Delete in one row on a '
        '360dp phone: $code', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, locale: Locale(code));
      final l10n = tester.element(find.byType(BottomSheet)).l10n;
      await tester.tap(find.text(l10n.libraryDeleteCollectionButton));
      await tester.pumpAndSettle();

      final keep = tester.getRect(
        find.widgetWithText(FilledButton, l10n.commonKeep),
      );
      final delete = tester.getRect(
        find.widgetWithText(OutlinedButton, l10n.commonDelete),
      );
      expect(keep.top, delete.top, reason: 'short labels share one row');
      expect(keep.height, AppSizes.buttonHeight);
      expect(delete.height, AppSizes.buttonHeight);
      expect(keep.width, delete.width);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('discard confirmation keeps editing filled, Discard outlined', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.pump();
    // No Cancel beside Save: leaving goes through the header's Close.
    expect(find.byType(OutlinedButton), findsNothing);
    await tester.tap(find.byTooltip('Close'));
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

  List<LibrarySource> twoSources() => [
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

  List<LibrarySource> manySources(int count) => [
    for (var i = 0; i < count; i++)
      LibrarySource.fromBook(
        Book(
          id: 'book-$i',
          title: 'Book $i',
          filePath: '/book.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
        ),
      ),
  ];

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('fixed layout: delete shares the count row, hairlines and '
        'footer follow the sheet rhythm ($locale)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await open(tester, sources: twoSources(), locale: locale);
        final rtl = locale.languageCode == 'ar';
        final sheet = tester.getRect(find.byType(BottomSheet));
        double start(Rect r) =>
            rtl ? sheet.right - r.right : r.left - sheet.left;
        double end(Rect r) => rtl ? r.left - sheet.left : sheet.right - r.right;
        expect(find.byType(CustomScrollView), findsNothing);

        final bookIcon = tester.getRect(find.byIcon(AppIcons.book));
        expect(start(bookIcon), closeTo(AppSpacing.xl, .01));

        final strings = tester.element(find.byType(BottomSheet)).l10n;
        final countLabel = find.text(
          '${strings.libraryBookCount(1)}, ${strings.libraryArticleCount(1)}',
        );
        final deleteButton = find.byKey(
          const ValueKey('libraryDeleteCollectionButton'),
        );
        final deleteLabel = find.descendant(
          of: deleteButton,
          matching: find.byType(AppButtonLabel),
        );
        expect(countLabel, findsOneWidget);
        expect(deleteLabel, findsOneWidget);
        expect(
          find.descendant(of: deleteButton, matching: find.byType(Icon)),
          findsNothing,
        );
        final countRect = tester.getRect(countLabel);
        final buttonRect = tester.getRect(deleteButton);
        // Count on the gutter; the label ends on it with the ink outset 8dp.
        expect(start(countRect), closeTo(AppSpacing.xl, .01));
        expect(end(tester.getRect(deleteLabel)), closeTo(AppSpacing.xl, .01));
        expect(end(buttonRect), closeTo(AppSpacing.xl - AppSpacing.lg, .01));
        expect(buttonRect.height, AppSizes.buttonHeight);
        expect(countRect.center.dy, closeTo(buttonRect.center.dy, .5));
        // Directly under the name field.
        expect(
          buttonRect.top - tester.getRect(find.byType(TextField)).bottom,
          closeTo(AppSpacing.lg, .01),
        );
        final style = tester.widget<TextButton>(deleteButton).style!;
        expect(
          style.foregroundColor!.resolve({}),
          tester.element(deleteButton).colors.error,
        );
        expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);
        expect(
          find.byKey(const ValueKey('libraryDeleteCollectionDivider')),
          findsNothing,
        );

        final rowDivider = tester.getRect(
          find.byKey(const ValueKey('collectionSourceDivider-book')),
        );
        expect(start(rowDivider), closeTo(AppSpacing.xl, .01));
        expect(end(rowDivider), closeTo(AppSpacing.xl, .01));
        final lastRow = tester.getRect(
          find.byKey(const ValueKey('collectionSource-article')),
        );
        final save = tester.getRect(find.byType(FilledButton));
        // The list's own 16dp bottom plus the footer's 8dp top; the fixed
        // layout's few spare estimate pixels sit above the command.
        expect(save.top - lastRow.bottom, closeTo(AppSpacing.xl, 4));
        expect(844 - save.bottom, closeTo(AppSpacing.lg * 2, .01));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('scrolling layout keeps the same gaps around the delete entry '
      'and commands', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    // Above 1.33x the form uses one scrolling viewport.
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, sources: manySources(12));
    expect(find.byType(CustomScrollView), findsOneWidget);

    // Delete sits on the count row under the name field, not above the
    // footer; "12 books" and the label still share the line at this scale.
    final deleteButton = find.byKey(
      const ValueKey('libraryDeleteCollectionButton'),
    );
    final countRect = tester.getRect(find.text('12 books'));
    final deleteLabel = find.descendant(
      of: deleteButton,
      matching: find.byType(AppButtonLabel),
    );
    expect(countRect.left, closeTo(AppSpacing.xl, .01));
    expect(
      tester.getRect(deleteLabel).right,
      closeTo(390 - AppSpacing.xl, .01),
    );
    expect(
      countRect.center.dy,
      closeTo(tester.getRect(deleteButton).center.dy, .5),
    );
    expect(
      tester.getRect(deleteButton).top -
          tester.getRect(find.byType(TextField)).bottom,
      closeTo(AppSpacing.lg, .5),
    );
    expect(
      find.byKey(const ValueKey('libraryDeleteCollectionDivider')),
      findsNothing,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final lastRowIcon = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('collectionSource-book-11')),
        matching: find.byIcon(AppIcons.book),
      ),
    );
    expect(lastRowIcon.left, closeTo(AppSpacing.xl, .01));
    final rowDivider = tester.getRect(
      find.byKey(const ValueKey('collectionSourceDivider-book-10')),
    );
    expect(rowDivider.left, closeTo(AppSpacing.xl, .01));
    expect(rowDivider.right, closeTo(390 - AppSpacing.xl, .01));
    final lastRow = tester.getRect(
      find.byKey(const ValueKey('collectionSource-book-11')),
    );
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    // The list's own 16dp bottom plus the footer's 8dp top.
    expect(save.top - lastRow.bottom, closeTo(AppSpacing.xl, .01));
    expect(844 - save.bottom, closeTo(AppSpacing.lg * 2, .01));
    // The scrolling layout keeps the single command on the 24dp gutters.
    expect(save.left, closeTo(AppSpacing.xl, .01));
    expect(save.right, closeTo(390 - AppSpacing.xl, .01));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a delete entry the commands follow 24dp after the last '
      'row', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Enough rows to exceed the step's minimum height.
    await open(tester, sources: manySources(3), favourites: true);
    expect(
      find.byKey(const ValueKey('libraryDeleteCollectionButton')),
      findsNothing,
    );
    final lastRow = tester.getRect(
      find.byKey(const ValueKey('collectionSource-book-2')),
    );
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    expect(save.top - lastRow.bottom, closeTo(AppSpacing.xl, 4));
    expect(844 - save.bottom, closeTo(AppSpacing.lg * 2, .01));
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('narrow viewport at 2x text stacks the count row with Delete '
        'at the end ($locale)', (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        await open(tester, sources: twoSources(), locale: locale);
        final rtl = locale.languageCode == 'ar';
        double start(Rect r) => rtl ? 320 - r.right : r.left;
        double end(Rect r) => rtl ? r.left : 320 - r.right;
        final strings = tester.element(find.byType(BottomSheet)).l10n;
        final countRect = tester.getRect(
          find.text(
            '${strings.libraryBookCount(1)}, '
            '${strings.libraryArticleCount(1)}',
          ),
        );
        final deleteButton = find.byKey(
          const ValueKey('libraryDeleteCollectionButton'),
        );
        final buttonRect = tester.getRect(deleteButton);
        final labelRect = tester.getRect(
          find.descendant(
            of: deleteButton,
            matching: find.byType(AppButtonLabel),
          ),
        );
        expect(start(countRect), closeTo(AppSpacing.xl, .01));
        expect(buttonRect.top, greaterThanOrEqualTo(countRect.bottom));
        expect(end(labelRect), closeTo(AppSpacing.xl, .01));
        expect(end(buttonRect), closeTo(AppSpacing.xl - AppSpacing.lg, .01));
        expect(buttonRect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
        expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();
        expect(find.text(strings.libraryDeleteCollectionTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('manage step shows one full-width Save on the 24dp gutters and '
      'no secondary', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, sources: twoSources());
      final step = find.byKey(const ValueKey('manageCollectionContent'));
      expect(
        find.descendant(of: step, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: step, matching: find.byType(OutlinedButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: step, matching: find.byType(AppSheetActions)),
        findsNothing,
      );
      expect(find.text('Cancel'), findsNothing);
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
      expect(save.left, closeTo(AppSpacing.xl, .01));
      expect(save.right, closeTo(390 - AppSpacing.xl, .01));
      expect(save.height, AppSizes.buttonHeight);
      expect(844 - save.bottom, closeTo(AppSpacing.lg * 2, .01));
      expect(find.byTooltip('Close'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Save shows a busy spinner and keeps its size while writing', (
    tester,
  ) async {
    await open(tester, sources: twoSources());
    await tester.tap(find.byKey(const ValueKey('collectionSourceRemove-book')));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    repository.writeGate = gate;
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(find.byType(OutlinedButton), findsNothing);
    final saveRect = tester.getRect(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.descendant(of: save, matching: find.byType(ButtonLoadingIndicator)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppBusyButtonLabel>(
            find.descendant(
              of: save,
              matching: find.byType(AppBusyButtonLabel),
            ),
          )
          .busy,
      isTrue,
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(tester.getRect(save), saveRect);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('libraryDeleteCollectionButton')),
          )
          .onPressed,
      isNull,
    );
    // Close waits for the write rather than asking or leaving.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester
          .widget<AppPlainIconButton>(
            find.byKey(const ValueKey('collectionSourceRemove-article')),
          )
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'article'});
  });

  testWidgets('delete confirmation body is start-aligned on the 24dp gutter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, sources: twoSources(), locale: const Locale('ar'));
    await tester.tap(
      find.byKey(const ValueKey('libraryDeleteCollectionButton')),
    );
    await tester.pumpAndSettle();
    final strings = tester.element(find.byType(BottomSheet)).l10n;
    final body = find.text(strings.libraryDeleteCollectionBody('Reading'));
    final header = tester.getRect(find.byType(BottomSheetHeader));
    final bodyRect = tester.getRect(body);
    expect(tester.widget<Text>(body).textAlign, isNull);
    expect(bodyRect.right, closeTo(390 - AppSpacing.xl, .01));
    expect(bodyRect.top, closeTo(header.bottom + AppSpacing.sm, .01));
    final actions = tester.getRect(find.byType(AppSheetActions));
    expect(actions.top - bodyRect.bottom, greaterThanOrEqualTo(AppSpacing.xl));
    expect(844 - actions.bottom, closeTo(AppSpacing.lg * 2, .01));
  });
}
