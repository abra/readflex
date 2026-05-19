import 'package:catalog/src/catalog_list_view.dart';
import 'package:catalog/src/catalog_selection_cubit.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _books = [
  Book(
    id: 'b-1',
    title: 'First Book',
    author: 'Author',
    filePath: '/books/first.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  ),
  Book(
    id: 'b-2',
    title: 'Second Book',
    author: 'Author',
    filePath: '/books/second.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  ),
];

void main() {
  testWidgets('list separators span the cover column above shadows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CatalogListView(
            books: _books,
            selection: const CatalogSelectionState(),
            scrollController: ScrollController(),
            onBookPressed: (_) {},
            onBookLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      ),
    );

    final dividerFinder = find.byKey(
      const ValueKey('catalogListRowTopDivider'),
    );
    expect(dividerFinder, findsOneWidget);

    final dividerTop = tester.getTopLeft(dividerFinder).dy;
    final dividerLeft = tester.getTopLeft(dividerFinder).dx;
    final firstTitleTop = tester.getTopLeft(find.text('First Book')).dy;
    final secondTitleOffset = tester.getTopLeft(find.text('Second Book'));

    expect(dividerTop, greaterThan(firstTitleTop));
    expect(dividerTop, lessThan(secondTitleOffset.dy));
    expect(dividerLeft, AppSpacing.lg);
    expect(dividerLeft, lessThan(secondTitleOffset.dx));
  });
}
