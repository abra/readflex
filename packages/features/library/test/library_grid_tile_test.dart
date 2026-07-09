import 'package:library_feature/src/library_grid_tile.dart';
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
  testWidgets('grid tile exposes source semantics and reader action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final openedBook = _book.copyWith(
      readingProgress: 0.42,
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
                onLongPress: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Flutter in Action')),
      matchesSemantics(
        label: 'Flutter in Action',
        value: 'Book, Eric Windmill, EPUB, 42 percent read',
        isButton: true,
        hasTapAction: true,
        hasLongPressAction: true,
        onTapHint: 'Open reader',
        onLongPressHint: 'Select source',
      ),
    );

    semantics.dispose();
  });

  testWidgets('selected grid tile exposes selection tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

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
                isSelectionMode: true,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Flutter in Action')),
      matchesSemantics(
        label: 'Flutter in Action',
        value: 'Book, Eric Windmill, EPUB, New',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        hasLongPressAction: true,
        onTapHint: 'Deselect source',
      ),
    );

    semantics.dispose();
  });

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

  testWidgets('article grid fallback cover uses RTL text direction', (
    tester,
  ) async {
    final rtlArticle = Article(
      id: 'a-rtl',
      title: 'الأزمة الاقتصادية تتصدر الاهتمامات',
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
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: BookLibraryGridTile(
                source: LibrarySource.fromArticle(rtlArticle),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final cover = tester.widget<AppSourceCover>(find.byType(AppSourceCover));
    final title = tester.widget<Text>(find.text(rtlArticle.title));
    final source = tester.widget<Text>(find.text('الجزيرة'));
    final coverRect = tester.getRect(find.byType(AppSourceCoverFrame));
    final titleRect = tester.getRect(find.text(rtlArticle.title));
    final sourceRect = tester.getRect(find.text('الجزيرة'));

    expect(cover.textDirection, TextDirection.rtl);
    expect(title.textDirection, TextDirection.rtl);
    expect(title.textAlign, TextAlign.start);
    expect(source.textDirection, TextDirection.rtl);
    expect(source.textAlign, TextAlign.start);
    expect(titleRect.right, closeTo(coverRect.right - 12, 1));
    expect(sourceRect.right, closeTo(coverRect.right - 12, 1));
  });

  testWidgets('grid progress bar uses equal compact edge insets', (
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

    final coverRect = tester.getRect(find.byType(AppSourceCoverFrame));
    final progressRect = tester.getRect(
      find.byKey(const Key('libraryGridProgressBar')),
    );
    expect(progressRect.left, coverRect.left + AppSpacing.xxs);
    expect(progressRect.right, coverRect.right - AppSpacing.xxs);
    expect(progressRect.bottom, coverRect.bottom - AppSpacing.xxs);
  });

  testWidgets('grid progress bar is hidden until source is opened', (
    tester,
  ) async {
    await _pumpGridTile(tester, LibrarySource.fromBook(_book));

    expect(find.byKey(const Key('libraryGridProgressBar')), findsNothing);
    expect(find.byKey(const Key('libraryGridProgressFill')), findsNothing);
  });

  testWidgets('grid progress bar appears for opened source at zero progress', (
    tester,
  ) async {
    final openedBook = _book.copyWith(lastOpenedAt: DateTime(2026, 1, 2));

    await _pumpGridTile(tester, LibrarySource.fromBook(openedBook));

    expect(find.byKey(const Key('libraryGridProgressBar')), findsOneWidget);
    expect(find.byKey(const Key('libraryGridProgressFill')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('libraryGridProgressFill'))).width,
      0,
    );
  });

  testWidgets('grid progress fill animates progress changes', (tester) async {
    final firstState = _book.copyWith(
      readingProgress: 0.2,
      lastOpenedAt: DateTime(2026, 1, 2),
    );
    final secondState = firstState.copyWith(readingProgress: 0.8);

    await _pumpGridTile(tester, LibrarySource.fromBook(firstState));

    final progressBarWidth = tester
        .getSize(find.byKey(const Key('libraryGridProgressBar')))
        .width;
    final initialFillWidth = tester
        .getSize(find.byKey(const Key('libraryGridProgressFill')))
        .width;
    expect(initialFillWidth, closeTo(progressBarWidth * 0.2, 1));

    await _pumpGridTile(tester, LibrarySource.fromBook(secondState));
    await tester.pump(const Duration(milliseconds: 120));

    final midFillWidth = tester
        .getSize(find.byKey(const Key('libraryGridProgressFill')))
        .width;
    expect(midFillWidth, greaterThan(initialFillWidth));
    expect(midFillWidth, lessThan(progressBarWidth * 0.8));

    await tester.pumpAndSettle();

    final finalFillWidth = tester
        .getSize(find.byKey(const Key('libraryGridProgressFill')))
        .width;
    expect(finalFillWidth, closeTo(progressBarWidth * 0.8, 1));
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

Future<void> _pumpGridTile(
  WidgetTester tester,
  LibrarySource source,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            height: 180,
            child: BookLibraryGridTile(
              source: source,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
}
