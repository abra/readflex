import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:local_storage/local_storage.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// Library landing states that only appear for a new or returning reader:
/// the empty library's two import entries, the Continue reading card, and the
/// built-in Books / Comics / New collections of a mixed library.
void main() {
  setUpAll(loadUiFonts);

  Widget libraryScreen(UiTestApp app) => LibraryScreen(
    bookRepository: app.bookRepository,
    articleRepository: app.articleRepository,
    collectionRepository: app.collectionRepository,
    preferencesService: app.preferencesService,
    onSourcePressed: (_, {onSourceOpened}) async {},
    onAddPressed:
        ({required onImported, entry = LibraryImportEntry.menu}) async {},
  );

  for (final profile in VisualProfile.values) {
    testWidgets('empty library ${profile.name}', (tester) async {
      final app = await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      );
      addTearDown(app!.dispose);
      await pumpGoldenSurface(tester, profile, (_) => libraryScreen(app));
      await waitForUi(
        tester,
        () => find.byType(FilledButton).evaluate().isNotEmpty,
        description: 'empty library actions',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectUiGolden(tester, profile, 'library-empty');
      // Short and large-text screens scroll the entries into reach.
      for (final button in [
        find.byType(FilledButton),
        find.byType(OutlinedButton),
      ]) {
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
      }
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('continue reading ${profile.name}', (tester) async {
      final app = await tester.runAsync(() => UiTestApp.create());
      addTearDown(app!.dispose);
      await tester.runAsync(
        () => app.database.booksDao.updateBook(
          BooksTableCompanion(
            id: Value(app.book!.id),
            readingProgress: const Value(.42),
            lastOpenedAt: Value(DateTime(2026, 10, 7).toIso8601String()),
          ),
        ),
      );
      await pumpGoldenSurface(tester, profile, (_) => libraryScreen(app));
      final card = find.byKey(const ValueKey('libraryContinueReadingCard'));
      await waitForUi(
        tester,
        () => card.evaluate().isNotEmpty,
        description: 'continue reading card',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: card,
          matching: find.text(ReadingFixture.bookTitle),
        ),
        findsOneWidget,
      );
      // The card is the book's place: it is not repeated as a cover below.
      expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectUiGolden(tester, profile, 'library-continue-reading');

      // Long-press selects the card's book in place, like a row.
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await expectUiGolden(
        tester,
        profile,
        'library-continue-reading-selected',
      );
      await unmountUi(tester);
    }, tags: ['golden']);

    testWidgets('built-in collections ${profile.name}', (tester) async {
      final app = await tester.runAsync(() => UiTestApp.create());
      addTearDown(app!.dispose);
      await tester.runAsync(() async {
        // Opened, so New holds only the comic and is worth listing.
        await app.database.booksDao.updateBook(
          BooksTableCompanion(
            id: Value(app.book!.id),
            lastOpenedAt: Value(DateTime(2026, 10, 7).toIso8601String()),
          ),
        );
        await app.database.booksDao.insertBook(
          BooksTableCompanion.insert(
            id: 'ui-fixture-comic',
            title: 'Panel Studies',
            filePath: 'panels.cbz',
            format: BookFormat.cbz.name,
            addedAt: DateTime(2026, 2).toIso8601String(),
          ),
        );
      });
      await pumpGoldenSurface(tester, profile, (_) => libraryScreen(app));
      final collections = find.byKey(
        const ValueKey('libraryCollectionsButton'),
      );
      await waitForUi(
        tester,
        () => collections.evaluate().isNotEmpty,
        description: 'Collections button',
      );
      await tester.pumpAndSettle();
      await tapUi(tester, collections);
      for (final type in ['books', 'comics', 'unread']) {
        expect(
          find.byKey(ValueKey('collectionScopeRow-$type-$type')),
          findsOneWidget,
          reason: type,
        );
      }
      expect(
        find.byKey(const ValueKey('collectionScopeRow-articles-articles')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await expectUiGolden(tester, profile, 'collection-picker-built-ins');

      await tapUi(
        tester,
        find.byKey(const ValueKey('collectionScopeRow-comics-comics')),
      );
      expect(find.text('Panel Studies'), findsWidgets);
      expect(find.text(ReadingFixture.bookTitle), findsNothing);
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
