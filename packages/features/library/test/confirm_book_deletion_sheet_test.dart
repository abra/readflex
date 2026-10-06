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

  testWidgets('cancel is the filled default and delete the outlined action', (
    tester,
  ) async {
    BookDeletionScope? result;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showConfirmBookDeletionSheet(context, count: 2);
                completed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancel = find.widgetWithText(FilledButton, 'Cancel');
    final delete = find.widgetWithText(OutlinedButton, 'Delete');
    expect(cancel, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsNothing);
    final colors = Theme.of(tester.element(delete)).colorScheme;
    final style = tester.widget<OutlinedButton>(delete).style!;
    expect(style.foregroundColor!.resolve({}), colors.error);
    expect(style.side!.resolve({})!.color, colors.error);
    expect(tester.getCenter(delete).dx, lessThan(tester.getCenter(cancel).dx));

    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('Delete 2 items?'), findsNothing);
  });
}
