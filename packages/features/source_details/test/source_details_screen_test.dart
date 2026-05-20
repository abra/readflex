import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:source_details/source_details.dart';

final _newSource = Book(
  id: 'source-1',
  title: 'Flutter Design Patterns',
  author: 'Daria Orlova',
  filePath: '/book.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

final _article = Article(
  id: 'article-1',
  title: 'Saved Article',
  url: 'https://example.com/article',
  author: 'Article Author',
  siteName: 'Example',
  contentPath: '/articles/article-1/article.json',
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  group('SourceDetailsScreen', () {
    late _FakeBookRepository repository;
    late _FakeArticleRepository articleRepository;
    late _FakeHighlightRepository highlightRepository;
    late _FakeFlashcardRepository flashcardRepository;
    late _FakeDictionaryRepository dictionaryRepository;

    setUp(() {
      repository = _FakeBookRepository()..source = _newSource;
      articleRepository = _FakeArticleRepository()..article = _article;
      highlightRepository = _FakeHighlightRepository()..count = 2;
      flashcardRepository = _FakeFlashcardRepository()..count = 3;
      dictionaryRepository = _FakeDictionaryRepository()..count = 4;
    });

    testWidgets('renders initial source details with start action', (
      tester,
    ) async {
      await tester.pumpSourceDetails(
        repository: repository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
        dictionaryRepository: dictionaryRepository,
        initialSource: LibrarySource.fromBook(_newSource),
      );

      expect(find.text('Flutter Design Patterns'), findsWidgets);
      expect(find.text('Daria Orlova'), findsOneWidget);
      expect(find.text('EPUB  •  New'), findsOneWidget);
      expect(find.text('Start reading'), findsOneWidget);
      expect(find.byIcon(AppIcons.back), findsOneWidget);
      expect(find.byType(AppBottomActionBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBottomActionBar),
          matching: find.byIcon(AppIcons.book),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.bookmark), findsNothing);
      expect(find.byIcon(AppIcons.moreHorizontal), findsNothing);
      expect(find.byType(Hero), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Dictionary'), findsOneWidget);
      expect(find.text('2 saved passages'), findsOneWidget);
      expect(find.text('3 cards created'), findsOneWidget);
      expect(find.text('4 words collected'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronRight), findsNWidgets(3));
    });

    testWidgets('article details show source instead of article author', (
      tester,
    ) async {
      repository.source = null;

      await tester.pumpSourceDetails(
        repository: repository,
        articleRepository: articleRepository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
        dictionaryRepository: dictionaryRepository,
        initialSource: LibrarySource.fromArticle(_article),
      );

      expect(find.text('Saved Article'), findsWidgets);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Article Author'), findsNothing);

      final coverArt = tester.widget<AppCoverArt>(find.byType(AppCoverArt));
      expect(coverArt.showTitle, isFalse);
      expect(coverArt.showArticleBadge, isFalse);
      expect(
        find.descendant(
          of: find.byType(AppSourceCoverFrame),
          matching: find.byIcon(AppIcons.language),
        ),
        findsOneWidget,
      );
      final articleIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(AppSourceCoverFrame),
          matching: find.byIcon(AppIcons.language),
        ),
      );
      expect(articleIcon.size, closeTo(73.6, 0.1));
    });

    testWidgets('hides review section for comics', (tester) async {
      final comicSource = _newSource.copyWith(
        title: 'Sample Comic',
        filePath: '/comic.cbz',
        format: BookFormat.cbz,
      );
      repository.source = comicSource;

      await tester.pumpSourceDetails(
        repository: repository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
        dictionaryRepository: dictionaryRepository,
        initialSource: LibrarySource.fromBook(comicSource),
      );

      expect(find.text('Sample Comic'), findsWidgets);
      expect(find.text('CBZ  •  New'), findsOneWidget);
      expect(find.text('Review'), findsNothing);
      expect(find.text('Highlights'), findsNothing);
      expect(find.text('Flashcards'), findsNothing);
      expect(find.text('Dictionary'), findsNothing);
      expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    });

    testWidgets(
      'shows continue action for opened source and invokes callback',
      (
        tester,
      ) async {
        final openedSource = _newSource.copyWith(
          lastOpenedAt: DateTime(2026, 1, 2),
        );
        repository.source = openedSource;
        Book? selectedSource;

        await tester.pumpSourceDetails(
          repository: repository,
          highlightRepository: highlightRepository,
          flashcardRepository: flashcardRepository,
          dictionaryRepository: dictionaryRepository,
          initialSource: LibrarySource.fromBook(openedSource),
          onReadPressed: (source, _) async => selectedSource = source,
        );

        await tester.tap(find.text('Continue reading'));
        await tester.pump();

        expect(selectedSource, openedSource);
      },
    );

    testWidgets('updates bottom action after source reloads from reader', (
      tester,
    ) async {
      await tester.pumpSourceDetails(
        repository: repository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
        dictionaryRepository: dictionaryRepository,
        initialSource: LibrarySource.fromBook(_newSource),
        onReadPressed: (source, _) async {
          repository.source = source.copyWith(
            lastOpenedAt: DateTime(2026, 1, 2),
          );
        },
      );

      expect(find.text('Start reading'), findsOneWidget);
      expect(find.text('Continue reading'), findsNothing);

      await tester.tap(find.text('Start reading'));
      await tester.pumpAndSettle();

      expect(find.text('Start reading'), findsNothing);
      expect(find.text('Continue reading'), findsOneWidget);
    });

    testWidgets('keeps source cover Hero bounds at stable 2:3 ratio', (
      tester,
    ) async {
      await tester.pumpSourceDetails(
        repository: repository,
        highlightRepository: highlightRepository,
        flashcardRepository: flashcardRepository,
        dictionaryRepository: dictionaryRepository,
        initialSource: LibrarySource.fromBook(_newSource),
      );

      final heroSize = tester.getSize(find.byType(Hero));

      expect(heroSize.width, 184);
      expect(heroSize.height, 276);
    });
  });
}

extension on WidgetTester {
  Future<void> pumpSourceDetails({
    required BookRepository repository,
    HighlightRepository? highlightRepository,
    FlashcardRepository? flashcardRepository,
    DictionaryRepository? dictionaryRepository,
    ArticleRepository? articleRepository,
    LibrarySource? initialSource,
    Future<void> Function(Book source, SourceType sourceType)? onReadPressed,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SourceDetailsScreen(
          sourceId: initialSource?.id ?? 'source-1',
          bookRepository: repository,
          articleRepository: articleRepository,
          highlightRepository:
              highlightRepository ?? _FakeHighlightRepository(),
          flashcardRepository:
              flashcardRepository ?? _FakeFlashcardRepository(),
          dictionaryRepository:
              dictionaryRepository ?? _FakeDictionaryRepository(),
          initialSource: initialSource,
          onReadPressed: onReadPressed ?? (_, _) async {},
        ),
      ),
    );
    await pump();
  }
}

class _FakeBookRepository implements BookRepository {
  Book? source;

  @override
  Future<Book?> getBookById(String id) async =>
      source?.id == id ? source : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeArticleRepository implements ArticleRepository {
  Article? article;

  @override
  Future<Article?> getArticleById(String id) async =>
      article?.id == id ? article : null;

  @override
  Book toReaderBook(Article article) => Book(
    id: article.id,
    title: article.title,
    author: article.author ?? article.siteName ?? article.hostname,
    coverImagePath: article.coverImagePath,
    format: BookFormat.epub,
    filePath: article.epubPath,
    currentCfi: article.currentCfi,
    readingProgress: article.readingProgress,
    addedAt: article.addedAt,
    lastOpenedAt: article.lastOpenedAt,
    isFinished: article.isFinished,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHighlightRepository implements HighlightRepository {
  int count = 0;

  @override
  Future<int> getHighlightCountBySource(String sourceId) async => count;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFlashcardRepository implements FlashcardRepository {
  int count = 0;

  @override
  Future<int> getFlashcardCountByDeck(String deckId) async => count;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDictionaryRepository implements DictionaryRepository {
  int count = 0;

  @override
  Future<int> getEntryCountBySource(String sourceId) async => count;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
