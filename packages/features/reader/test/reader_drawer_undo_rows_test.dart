import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_swipe_to_delete.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  final book = Book(
    id: 'book',
    title: 'Book',
    filePath: '/book.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  );
  Highlight highlight(String id, String text, DateTime createdAt) => Highlight(
    id: id,
    sourceId: book.id,
    sourceType: SourceType.book,
    text: text,
    cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
    progress: .2,
    createdAt: createdAt,
  );
  final newer = highlight('newer', 'Newer passage', DateTime(2026, 2));
  final older = highlight('older', 'Older passage', DateTime(2026, 1));
  SourceBookmark bookmark(String id, String content, double progress) =>
      SourceBookmark(
        id: id,
        sourceId: book.id,
        sourceType: SourceType.book,
        cfi: 'epubcfi(/6/$id)',
        content: content,
        progress: progress,
        createdAt: DateTime(2026),
      );
  final first = bookmark('first', 'First page', .1);
  final second = bookmark('second', 'Second page', .5);

  late FakeBookRepository books;
  late FakeHighlightRepository highlights;
  late ReaderBloc bloc;

  Future<void> load() async {
    books = FakeBookRepository()
      ..seedBook(book)
      ..seedBookmarks(book.id, [first, second]);
    highlights = FakeHighlightRepository()
      ..seedHighlights(book.id, [newer, older]);
    bloc = ReaderBloc(
      bookRepository: books,
      highlightRepository: highlights,
      initialSource: book,
    );
    addTearDown(bloc.close);
    bloc.add(ReaderSourceLoadRequested(sourceId: book.id));
    await bloc.stream
        .firstWhere((s) => s.highlights.length == 2 && s.bookmarks.length == 2)
        .timeout(const Duration(seconds: 3));
  }

  /// Phone-sized, so the half-height Contents sheet shows every row.
  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: Stack(
              children: [
                ReaderTocDrawerDriver(
                  loadThumbnail: (_) async => null,
                  visible: true,
                  format: BookFormat.epub,
                  pageProgressionRtl: false,
                  readerTheme: ReaderThemePreset.paper.data,
                  onClose: () {},
                  onItemSelected: (_) {},
                  onBookmarkSelected: (_) {},
                  onHighlightSelected: (_) {},
                  onBookmarkDeleted: (b) => bloc.add(
                    ReaderBookmarkDeleted(sourceId: b.sourceId, id: b.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  ReaderHighlightListTile tile(WidgetTester tester, String id) =>
      tester.widget<ReaderHighlightListTile>(find.byKey(ValueKey(id)));

  testWidgets('a popup-deleted highlight keeps its row with Undo', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await openTab(tester, l10n.readerHighlights);

    bloc.add(const ReaderHighlightDeleteRequested(highlightId: 'older'));
    await tester.pumpAndSettle();
    expect(bloc.state.highlights, [newer]);
    expect(find.text(l10n.readerHighlightRemoved), findsOneWidget);
    expect(find.text('Older passage'), findsOneWidget);
    expect(tile(tester, 'older').removed, isTrue);
    expect(tile(tester, 'newer').removed, isFalse);
    // The row stays below the newer passage, where it was.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('older'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('newer'))).dy),
    );
    final undo = find.byTooltip(l10n.commonUndo);
    expect(undo, findsOneWidget);
    expect(find.byIcon(AppIcons.undo), findsOneWidget);

    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(bloc.state.highlights, hasLength(2));
    expect(bloc.state.highlightEdits.removed, isEmpty);
    expect(find.text(l10n.readerHighlightRemoved), findsNothing);
    expect(find.byIcon(AppIcons.undo), findsNothing);
    expect(find.text('Older passage'), findsOneWidget);
    expect(find.text('Newer passage'), findsOneWidget);
  });

  testWidgets('a removed highlight still counts as content for filters', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await openTab(tester, l10n.readerHighlights);
    bloc
      ..add(const ReaderHighlightDeleteRequested(highlightId: 'older'))
      ..add(const ReaderHighlightDeleteRequested(highlightId: 'newer'));
    await tester.pumpAndSettle();
    expect(bloc.state.highlights, isEmpty);
    expect(find.byType(EmptyState), findsNothing);
    expect(find.byType(AppFilterChip), findsOneWidget);
    expect(find.byIcon(AppIcons.undo), findsNWidgets(2));

    bloc.add(const ReaderHighlightUndoDismissed());
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.undo), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('only the restoring highlight row is disabled', (tester) async {
    await load();
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await openTab(tester, l10n.readerHighlights);
    bloc
      ..add(const ReaderHighlightDeleteRequested(highlightId: 'older'))
      ..add(const ReaderHighlightDeleteRequested(highlightId: 'newer'));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    highlights.addGate = gate.future;
    bloc.add(const ReaderHighlightRestored(highlightId: 'older'));
    await tester.pumpAndSettle();
    expect(bloc.state.highlightEdits.busyId, 'older');
    expect(tile(tester, 'older').onUndo, isNull);
    expect(tile(tester, 'newer').onUndo, isNotNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(bloc.state.highlightEdits.busyId, isNull);
    expect(bloc.state.highlightEdits.removed.map((h) => h.id), ['newer']);
  });

  testWidgets('a failed restore keeps the row retryable', (tester) async {
    await load();
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await openTab(tester, l10n.readerHighlights);
    bloc.add(const ReaderHighlightDeleteRequested(highlightId: 'older'));
    await tester.pumpAndSettle();
    highlights.shouldThrow = true;
    await tester.tap(find.byTooltip(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(tile(tester, 'older').failed, isTrue);
    expect(find.textContaining(l10n.readerHighlightSaveFailed), findsOneWidget);
    highlights.shouldThrow = false;
    await tester.tap(find.byTooltip(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(bloc.state.highlights, hasLength(2));
    expect(find.byIcon(AppIcons.undo), findsNothing);
  });

  testWidgets('removed bookmark title drops to the muted color', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final context = tester.element(find.byType(Scaffold));
    final l10n = context.l10n;
    await openTab(tester, l10n.readerBookmarks);
    expect(
      tester.widget<Text>(find.text('First page')).style?.color,
      context.colors.onSurface,
    );
    await tester.drag(find.text('First page'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(find.text(l10n.readerBookmarkRemoved), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('First page')).style?.color,
      context.colors.onSurfaceVariant,
    );
    expect(
      tester.widget<Text>(find.text('Second page')).style?.color,
      context.colors.onSurface,
    );
  });

  testWidgets('a busy bookmark row leaves the other rows actionable', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await openTab(tester, l10n.readerBookmarks);
    await tester.drag(find.text('First page'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    books.restoreGate = gate.future;
    await tester.tap(find.byTooltip(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarkEdits.busyId, 'first');
    final undo = tester.widget<AppPlainIconButton>(
      find.ancestor(
        of: find.byIcon(AppIcons.undo),
        matching: find.byType(AppPlainIconButton),
      ),
    );
    expect(undo.onPressed, isNull);
    final swipe = tester.widget<ReaderSwipeToDelete>(
      find.ancestor(
        of: find.text('Second page'),
        matching: find.byType(ReaderSwipeToDelete),
      ),
    );
    expect(swipe.onDelete, isNotNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarkEdits, const ReaderBookmarkEdits());
    expect(bloc.state.bookmarks, hasLength(2));
  });
}
