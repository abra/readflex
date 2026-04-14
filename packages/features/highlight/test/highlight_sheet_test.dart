import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_highlight_repository.dart';

const _selection = TextSelectionContext(
  selectedText: 'Important passage',
  sourceId: 'book-1',
  sourceType: SourceType.book,
);

void main() {
  late FakeHighlightRepository repository;

  setUp(() {
    repository = FakeHighlightRepository();
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: HighlightSheet(
          highlightRepository: repository,
          selection: _selection,
        ),
      ),
    ),
  );

  testWidgets('renders title and selected text', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Important passage'), findsOneWidget);
  });

  testWidgets('renders color picker row with circular containers', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    // Each color circle is a 32x32 Container inside a GestureDetector.
    // Verify we have at least as many as HighlightColor values.
    final containers = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == 32 &&
          widget.constraints?.maxHeight == 32,
    );
    expect(containers, findsNWidgets(HighlightColor.values.length));
  });

  testWidgets('renders note field', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Add a note (optional)'), findsOneWidget);
  });

  testWidgets('save button is enabled by default', (tester) async {
    await tester.pumpWidget(buildSubject());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows error message on save failure', (tester) async {
    repository.shouldThrow = true;
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Failed to save highlight'), findsOneWidget);
  });

  testWidgets('successful save adds highlight to repository', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.highlights, hasLength(1));
    expect(repository.highlights.first.text, 'Important passage');
    expect(repository.highlights.first.sourceId, 'book-1');
  });

  testWidgets('note is passed to repository on save', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byType(TextField), 'My note');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.highlights.first.note, 'My note');
  });
}
