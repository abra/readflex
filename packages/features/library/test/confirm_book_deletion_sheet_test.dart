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

  testWidgets('Keep is the filled default and Delete the outlined action', (
    tester,
  ) async {
    BookDeletionScope? result;
    var completed = false;
    final semantics = tester.ensureSemantics();

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

    final keep = find.widgetWithText(FilledButton, 'Keep');
    final delete = find.widgetWithText(OutlinedButton, 'Delete');
    expect(keep, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsNothing);
    final colors = Theme.of(tester.element(delete)).colorScheme;
    final style = tester.widget<OutlinedButton>(delete).style!;
    expect(style.foregroundColor!.resolve({}), colors.error);
    expect(style.side!.resolve({})!.color, colors.error);
    expect(tester.getCenter(delete).dx, lessThan(tester.getCenter(keep).dx));
    try {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }

    await tester.tap(keep);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('Delete 2 items?'), findsNothing);
  });

  testWidgets('commands follow the footer contract: 24dp after the body and '
      '16dp below', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showConfirmBookDeletionSheet(context, count: 1),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final layout = tester.widget<ActionBottomSheetLayout>(
      find.byType(ActionBottomSheetLayout),
    );
    expect(layout.footer, isA<AppSheetActions>());
    expect(layout.footerPadding, ActionBottomSheetLayout.defaultFooterPadding);
    final body = tester.getRect(
      find.text('This removes the library items, highlights and bookmarks.'),
    );
    final actions = tester.getRect(find.byType(AppSheetActions));
    expect(body.left, AppSpacing.xl);
    expect(actions.left, AppSpacing.xl);
    expect(actions.right, 390 - AppSpacing.xl);
    expect(actions.top - body.bottom, closeTo(AppSpacing.xl, .01));
    // 16dp footer inset plus the route's max(16, safe inset).
    expect(844 - actions.bottom, closeTo(AppSpacing.lg * 2, .01));
  });
}
