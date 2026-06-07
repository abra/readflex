import 'package:library_feature/src/library_list_view.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
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

final _article = Article(
  id: 'a-1',
  title: 'Saved Article',
  url: 'https://example.com/article',
  siteName: 'Example',
  contentPath: '/articles/a-1/article.json',
  addedAt: DateTime(2026),
);

void main() {
  testWidgets('selected list cover border uses delete color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookLibraryListTile(
            source: LibrarySource.fromBook(_books.first),
            showTopDivider: false,
            isSelected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    final deleteColor = Theme.of(
      tester.element(find.byType(BookLibraryListTile)),
    ).colorScheme.error;
    final selectionDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .singleWhere(
          (decoration) =>
              decoration.border is Border &&
              (decoration.border! as Border).top.color == deleteColor &&
              (decoration.border! as Border).top.width == 2,
        );

    expect(selectionDecoration.color, deleteColor.withValues(alpha: 0.15));

    final coverRect = tester.getRect(find.byType(AppSourceCoverFrame));
    final checkRect = tester.getRect(
      find.byKey(const ValueKey('libraryListSelectionCheck')),
    );
    expect(checkRect.top, coverRect.top + AppSpacing.xs);
    expect(checkRect.right, coverRect.right - AppSpacing.xs);
  });

  testWidgets('list separators span the cover column above shadows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryListView(
            sources: _books.map(LibrarySource.fromBook).toList(),
            selection: const LibrarySelectionState(),
            scrollController: ScrollController(),
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      ),
    );

    final dividerFinder = find.byKey(
      const ValueKey('libraryListRowTopDivider'),
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

  testWidgets('article list row uses readable type label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LibraryListView(
            sources: [LibrarySource.fromArticle(_article)],
            selection: const LibrarySelectionState(),
            scrollController: ScrollController(),
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
          ),
        ),
      ),
    );

    expect(find.text('ARTICLE'), findsNothing);
    expect(find.text('Article'), findsWidgets);
    expect(find.text('Example'), findsWidgets);
  });

  testWidgets('RTL list row aligns source info to the right edge', (
    tester,
  ) async {
    final rtlArticle = Article(
      id: 'a-rtl',
      title: 'مقال عربي',
      url: 'https://example.com/ar',
      siteName: 'الجزيرة',
      language: 'ar',
      contentPath: '/articles/a-rtl/article.json',
      addedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BookLibraryListTile(
              source: LibrarySource.fromArticle(rtlArticle),
              showTopDivider: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(rtlArticle.title));
    final metaRow = tester.widget<Row>(
      find.byKey(const ValueKey('libraryListRowMeta')),
    );
    final rowRect = tester.getRect(find.byType(GestureDetector));
    final titleRect = tester.getRect(find.text(rtlArticle.title));

    expect(title.textDirection, TextDirection.rtl);
    expect(title.textAlign, TextAlign.start);
    expect(metaRow.textDirection, TextDirection.rtl);
    expect(titleRect.right, closeTo(rowRect.right - AppSpacing.xs, 1));
  });
}
