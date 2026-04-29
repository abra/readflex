import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/home.dart';

import 'helpers/fake_book_repository.dart';
// The home helpers file is named fake_flashcard_repository.dart but
// exports FakeFsrsRepository — matching the original bloc test setup.
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  testWidgets('renders Placeholder while UI is not implemented', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          bookRepository: FakeBookRepository(),
          highlightRepository: FakeHighlightRepository(),
          fsrsRepository: FakeFsrsRepository(),
          onBookPressed: (_) {},
          onPracticePressed: () {},
        ),
      ),
    );

    expect(find.byType(Placeholder), findsOneWidget);
  });
}
