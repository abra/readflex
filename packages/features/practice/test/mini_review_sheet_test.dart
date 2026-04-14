import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_fsrs_repository.dart';
import 'helpers/fake_highlight_repository.dart';

final _flashcard = Flashcard(
  id: 'fc-1',
  deckId: 'book-1',
  front: 'What is Flutter?',
  back: 'A UI toolkit',
  createdAt: DateTime(2026),
);

final _highlight = Highlight(
  id: 'hl-1',
  sourceId: 'book-1',
  sourceType: SourceType.book,
  text: 'Important quote',
  note: 'My note',
  color: HighlightColor.yellow,
  createdAt: DateTime(2026),
);

ReviewItem _reviewItem({
  required String itemId,
  required ReviewableType itemType,
}) => ReviewItem(
  itemId: itemId,
  itemType: itemType,
  sourceId: 'book-1',
  fsrs: const FsrsCardData(),
);

void main() {
  late FakeFsrsRepository fsrsRepository;
  late FakeFlashcardRepository flashcardRepository;
  late FakeHighlightRepository highlightRepository;
  late FakeDictionaryRepository dictionaryRepository;

  setUp(() {
    fsrsRepository = FakeFsrsRepository();
    flashcardRepository = FakeFlashcardRepository();
    highlightRepository = FakeHighlightRepository();
    dictionaryRepository = FakeDictionaryRepository();
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showMiniReviewSheet(
            context,
            sourceId: 'book-1',
            fsrsRepository: fsrsRepository,
            flashcardRepository: flashcardRepository,
            highlightRepository: highlightRepository,
            dictionaryRepository: dictionaryRepository,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  testWidgets('shows empty state when no due items', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('No items due for review.'), findsOneWidget);
  });

  testWidgets('shows flashcard content in reviewing state', (tester) async {
    fsrsRepository.dueItemsBySource = {
      'book-1': [
        _reviewItem(itemId: 'fc-1', itemType: ReviewableType.flashcard),
      ],
    };
    flashcardRepository.seed([_flashcard]);

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Mini Review'), findsOneWidget);
    expect(find.text('What is Flutter?'), findsOneWidget);
    expect(find.text('Show Answer'), findsOneWidget);
  });

  testWidgets('reveals answer when Show Answer tapped', (tester) async {
    fsrsRepository.dueItemsBySource = {
      'book-1': [
        _reviewItem(itemId: 'fc-1', itemType: ReviewableType.flashcard),
      ],
    };
    flashcardRepository.seed([_flashcard]);

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show Answer'));
    await tester.pumpAndSettle();

    expect(find.text('A UI toolkit'), findsOneWidget);
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
  });

  testWidgets('shows highlight content with Recall label', (tester) async {
    fsrsRepository.dueItemsBySource = {
      'book-1': [
        _reviewItem(itemId: 'hl-1', itemType: ReviewableType.highlight),
      ],
    };
    highlightRepository.seed([_highlight]);

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Important quote'), findsOneWidget);
    expect(find.text('Recall?'), findsOneWidget);
  });

  testWidgets('shows progress counter', (tester) async {
    fsrsRepository.dueItemsBySource = {
      'book-1': [
        _reviewItem(itemId: 'fc-1', itemType: ReviewableType.flashcard),
        _reviewItem(itemId: 'hl-1', itemType: ReviewableType.highlight),
      ],
    };
    flashcardRepository.seed([_flashcard]);
    highlightRepository.seed([_highlight]);

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('0/2'), findsOneWidget);
  });

  testWidgets('shows error state on failure', (tester) async {
    fsrsRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
