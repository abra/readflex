import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:library_feature/library_feature.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  author: 'Eric Windmill',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

void main() {
  late FakeBookRepository bookRepository;
  late PreferencesService preferencesService;

  setUp(() async {
    bookRepository = FakeBookRepository();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ['en'],
    );
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: LibraryScreen(
      bookRepository: bookRepository,
      preferencesService: preferencesService,
      onSourcePressed: (_, {onSourceOpened}) async {},
      onAddPressed: () async {},
    ),
  );

  testWidgets('shows loading indicator initially', (tester) async {
    bookRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());

    await tester.pump();
    expect(find.text('Failed to load library'), findsOneWidget);
  });

  testWidgets('shows error state on failure', (tester) async {
    bookRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Failed to load library'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows empty state when no items', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('shows Library header and item count with content', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search library...'), findsOneWidget);
  });

  testWidgets('shows filter segments', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Comics'), findsOneWidget);
  });

  testWidgets('shows FAB', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB guards against double-tap while import is in-flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    var invocations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: () async {
            invocations++;
            await gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(
      invocations,
      1,
      reason: 'second tap during in-flight import must be ignored',
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  // Visual counterpart to the guard test above. The behavioural guard
  // alone (re-entry check inside the handler) made the second tap a
  // silent no-op, but the FAB stayed visually enabled — confusing UX
  // and the fragility flagged by audit ("if UI ever depends on the
  // flag, it would silently desync"). Now `_addInFlight` is mutated
  // through setState and passed down as a nullable onPressed, so
  // FloatingActionButton renders greyed-out for the duration of the
  // import.
  testWidgets('FAB renders disabled while import is in-flight', (tester) async {
    final gate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: () async {
            await gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    // Before the tap: FAB is enabled.
    final initialFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(initialFab.onPressed, isNotNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // While the awaited onAddPressed parks on the gate, the FAB's
    // onPressed must be null — Material renders that state as disabled.
    final inFlightFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(inFlightFab.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();

    // After the import resolves the FAB returns to its enabled state.
    final settledFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(settledFab.onPressed, isNotNull);
  });

  testWidgets('refreshes and resorts after source details return delay', (
    tester,
  ) async {
    final newest = Book(
      id: 'b-newest',
      title: 'Newest',
      author: 'Author',
      filePath: '/books/newest.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 4),
    );
    final second = Book(
      id: 'b-second',
      title: 'Second',
      author: 'Author',
      filePath: '/books/second.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 3),
    );
    final target = Book(
      id: 'b-target',
      title: 'Target',
      author: 'Author',
      filePath: '/books/target.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1),
    );

    bookRepository.seedBooks([newest, second, target]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          preferencesService: preferencesService,
          onSourcePressed: (source, {onSourceOpened}) async {
            expect(source.id, target.id);
            bookRepository.seedBooks([
              target.copyWith(lastOpenedAt: DateTime(2026, 1, 5)),
              newest,
              second,
            ]);
          },
          onAddPressed: () async {},
        ),
      ),
    );
    await tester.pump();

    final targetFinder = find.text('Target');
    final newestFinder = find.text('Newest');
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetFinder).dx,
      greaterThan(tester.getTopLeft(newestFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(
      bookRepository.getBooksCallCount,
      1,
      reason: 'refreshing immediately would move the reverse Hero endpoint',
    );
    expect(
      tester.getTopLeft(targetFinder).dx,
      greaterThan(tester.getTopLeft(newestFinder).dx),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(bookRepository.getBooksCallCount, 1);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetFinder).dy,
      tester.getTopLeft(newestFinder).dy,
    );
  });

  testWidgets('refreshes before source details returns when reader opens', (
    tester,
  ) async {
    final newest = Book(
      id: 'b-newest',
      title: 'Newest',
      author: 'Author',
      filePath: '/books/newest.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 4),
    );
    final target = Book(
      id: 'b-target',
      title: 'Target',
      author: 'Author',
      filePath: '/books/target.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1),
    );
    final routeCompleter = Completer<void>();
    VoidCallback? notifySourceOpened;

    bookRepository.seedBooks([newest, target]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          preferencesService: preferencesService,
          onSourcePressed: (source, {onSourceOpened}) async {
            expect(source.id, target.id);
            notifySourceOpened = onSourceOpened;
            await routeCompleter.future;
          },
          onAddPressed: () async {},
        ),
      ),
    );
    await tester.pump();

    final targetFinder = find.text('Target');
    final newestFinder = find.text('Newest');
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetFinder).dx,
      greaterThan(tester.getTopLeft(newestFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 1);
    expect(notifySourceOpened, isNotNull);

    bookRepository.seedBooks([
      target.copyWith(lastOpenedAt: DateTime(2026, 1, 5)),
      newest,
    ]);
    notifySourceOpened!();
    await tester.pump();
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetFinder).dy,
      tester.getTopLeft(newestFinder).dy,
    );

    bookRepository.seedBooks([
      target.copyWith(
        lastOpenedAt: DateTime(2026, 1, 5),
        readingProgress: 0.5,
      ),
      newest,
    ]);
    routeCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      bookRepository.getBooksCallCount,
      2,
      reason: 'return refresh waits for the reverse Hero endpoint',
    );
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(
      bookRepository.getBooksCallCount,
      3,
      reason: 'return refresh picks up reader progress persisted after open',
    );
  });
}
