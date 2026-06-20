import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/confirm_book_deletion_sheet.dart';

void main() {
  testWidgets('delete confirmation keeps archived learning data', (
    tester,
  ) async {
    BookDeletionScope? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showConfirmBookDeletionSheet(
                      context,
                      count: 1,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this item?'), findsOneWidget);
    expect(find.text('Also delete archived learning data'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result, BookDeletionScope.keepLearningData);
  });
}
