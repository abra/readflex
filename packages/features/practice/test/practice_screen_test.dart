import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_fsrs_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  testWidgets('renders Placeholder while UI is not implemented', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          fsrsRepository: FakeFsrsRepository(),
          flashcardRepository: FakeFlashcardRepository(),
          highlightRepository: FakeHighlightRepository(),
          dictionaryRepository: FakeDictionaryRepository(),
        ),
      ),
    );

    expect(find.byType(Placeholder), findsOneWidget);
  });
}
