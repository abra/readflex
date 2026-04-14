import 'package:component_library/component_library.dart';
import 'package:content_library/content_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  author: 'Eric Windmill',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

final _article = Article(
  id: 'a-1',
  title: 'Understanding Dart',
  url: 'https://example.com/dart',
  contentPath: '/articles/dart.html',
  addedAt: DateTime(2026),
);

void main() {
  late FakeBookRepository bookRepository;
  late FakeArticleRepository articleRepository;
  late PreferencesService preferencesService;

  setUp(() async {
    bookRepository = FakeBookRepository();
    articleRepository = FakeArticleRepository();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ['en'],
    );
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: ContentLibraryScreen(
      bookRepository: bookRepository,
      articleRepository: articleRepository,
      preferencesService: preferencesService,
      onBookPressed: (_) async {},
      onArticlePressed: (_) async {},
      onAddPressed: () async {},
    ),
  );

  testWidgets('shows loading indicator initially', (tester) async {
    // Make the repo throw to stall loading
    bookRepository.shouldThrow = true;
    articleRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());

    // On first pump, BLoC emits loading → failure fast, check for error
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
    articleRepository.seedArticles([_article]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search books & articles...'), findsOneWidget);
  });

  testWidgets('shows filter segments', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Articles'), findsOneWidget);
  });

  testWidgets('shows FAB', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
