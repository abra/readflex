import 'package:catalog/src/catalog_grid_tile.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  author: 'Eric Windmill',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

void main() {
  testWidgets('selected grid cover border matches source cover radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: BookLibraryGridTile(
                book: _book,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final primary = Theme.of(
      tester.element(find.byType(BookLibraryGridTile)),
    ).colorScheme.primary;
    final selectionDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .singleWhere(
          (decoration) =>
              decoration.border is Border &&
              (decoration.border! as Border).top.color == primary &&
              (decoration.border! as Border).top.width == 3,
        );

    expect(
      selectionDecoration.borderRadius,
      BorderRadius.circular(appSourceCoverRadius),
    );
  });

  testWidgets('grid cover frame is symmetrically inset inside tap target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: BookLibraryGridTile(
                book: _book,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final tileRect = tester.getRect(find.byType(GestureDetector));
    final coverFrameRect = tester.getRect(find.byType(AppSourceCoverFrame));
    expect(coverFrameRect.left, tileRect.left + AppSpacing.xxs);
    expect(coverFrameRect.top, tileRect.top + AppSpacing.xxs);
    expect(coverFrameRect.right, tileRect.right - AppSpacing.xxs);
    expect(coverFrameRect.bottom, tileRect.bottom - AppSpacing.xxs);
  });
}
