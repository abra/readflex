import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_details/source_details.dart';

final _newSource = Book(
  id: 'source-1',
  title: 'Flutter Design Patterns',
  author: 'Daria Orlova',
  filePath: '/book.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  group('SourceDetailsScreen', () {
    late _FakeBookRepository repository;

    setUp(() {
      repository = _FakeBookRepository()..source = _newSource;
    });

    testWidgets('renders initial source details with start action', (
      tester,
    ) async {
      await tester.pumpSourceDetails(
        repository: repository,
        initialSource: _newSource,
      );

      expect(find.text('Flutter Design Patterns'), findsWidgets);
      expect(find.text('Daria Orlova'), findsOneWidget);
      expect(find.text('Start reading'), findsOneWidget);
      expect(find.byType(AppImageAspectRatio), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Dictionary'), findsOneWidget);
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
          initialSource: openedSource,
          onReadPressed: (source) async => selectedSource = source,
        );

        await tester.tap(find.text('Continue reading'));
        await tester.pump();

        expect(selectedSource, openedSource);
      },
    );
  });
}

extension on WidgetTester {
  Future<void> pumpSourceDetails({
    required BookRepository repository,
    Book? initialSource,
    Future<void> Function(Book source)? onReadPressed,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SourceDetailsScreen(
          sourceId: initialSource?.id ?? 'source-1',
          bookRepository: repository,
          initialSource: initialSource,
          onReadPressed: onReadPressed ?? (_) async {},
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
