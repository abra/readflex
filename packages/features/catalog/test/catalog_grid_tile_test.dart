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

final _article = Article(
  id: 'a-1',
  title: 'Saved Article',
  url: 'https://example.com/article',
  siteName: 'Example',
  contentPath: '/articles/a-1/article.json',
  addedAt: DateTime(2026),
);

void main() {
  testWidgets(
    'selected grid cover border uses delete color and source radius',
    (
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
                  source: LibrarySource.fromBook(_book),
                  isSelected: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final deleteColor = Theme.of(
        tester.element(find.byType(BookLibraryGridTile)),
      ).colorScheme.error;
      final selectionDecoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .singleWhere(
            (decoration) =>
                decoration.border is Border &&
                (decoration.border! as Border).top.color == deleteColor &&
                (decoration.border! as Border).top.width == 3,
          );

      expect(
        selectionDecoration.borderRadius,
        BorderRadius.circular(appSourceCoverRadius),
      );
    },
  );

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
                source: LibrarySource.fromBook(_book),
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

  testWidgets('article grid tile shows WEB badge instead of ARTICLE', (
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
                source: LibrarySource.fromArticle(_article),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('WEB'), findsOneWidget);
    expect(find.text('ARTICLE'), findsNothing);
    expect(find.text('Saved Article'), findsOneWidget);
    expect(find.text('EXAMPLE'), findsOneWidget);
    expect(find.byType(AppSourceCoverFrame), findsOneWidget);
  });

  testWidgets('grid fallback cover reserves space for progress overlay', (
    tester,
  ) async {
    final openedBook = _book.copyWith(
      readingProgress: 0.5,
      lastOpenedAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: BookLibraryGridTile(
                source: LibrarySource.fromBook(openedBook),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final sourceCover = tester.widget<AppSourceCover>(
      find.byType(AppSourceCover),
    );
    expect(sourceCover.bottomReserve, 16);
    expect(sourceCover.topAlignText, isTrue);
    expect(sourceCover.topReserve, 24);

    final coverRect = tester.getRect(find.byType(AppSourceCoverFrame));
    final titleRect = tester.getRect(find.text('Flutter in Action'));
    final authorRect = tester.getRect(find.text('ERIC WINDMILL'));
    final formatBadgeRect = tester.getRect(find.text('EPUB'));
    expect(titleRect.top, greaterThan(formatBadgeRect.bottom));
    expect(titleRect.top, lessThan(coverRect.top + 56));
    expect(authorRect.top, greaterThan(titleRect.bottom));
  });
}
