import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flashcard/flashcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_flashcard_repository.dart';

const _selection = TextSelectionContext(
  selectedText: 'Hello world',
  sourceId: 'book-1',
  sourceType: SourceType.book,
);

void main() {
  late FakeFlashcardRepository repository;

  setUp(() {
    repository = FakeFlashcardRepository();
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: FlashcardSheet(
          flashcardRepository: repository,
          selection: _selection,
        ),
      ),
    ),
  );

  testWidgets('renders title and selected text', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Create Flashcard'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('renders Front, Back, and Hint fields', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Hint (optional)'), findsOneWidget);
  });

  testWidgets('save button disabled when fields empty', (tester) async {
    await tester.pumpWidget(buildSubject());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('save button enabled when front and back filled', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextField, 'Front'),
      'term',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Back'),
      'definition',
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('save button stays disabled with only front filled', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextField, 'Front'),
      'term',
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows error message on save failure', (tester) async {
    repository.shouldThrow = true;
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextField, 'Front'),
      'term',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Back'),
      'definition',
    );
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Failed to save flashcard'), findsOneWidget);
  });

  testWidgets('successful save adds flashcard to repository', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.widgetWithText(TextField, 'Front'),
      'term',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Back'),
      'definition',
    );
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.flashcards, hasLength(1));
    expect(repository.flashcards.first.front, 'term');
    expect(repository.flashcards.first.back, 'definition');
  });
}
