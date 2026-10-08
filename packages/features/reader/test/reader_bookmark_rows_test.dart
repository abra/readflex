import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
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
  SourceBookmark bookmark(String id, String content, double progress) =>
      SourceBookmark(
        id: id,
        sourceId: book.id,
        sourceType: SourceType.book,
        cfi: 'epubcfi(/6/$id)',
        content: content,
        progress: progress,
        chapterTitle: 'Chapter',
        createdAt: DateTime(2026),
      );
  final first = bookmark('first', 'First page', .1);
  final second = bookmark('second', 'Second page', .5);

  late FakeBookRepository books;
  late ReaderBloc bloc;
  late List<SourceBookmark> deleted;

  Future<void> load() async {
    books = FakeBookRepository()
      ..seedBook(book)
      ..seedBookmarks(book.id, [first, second]);
    bloc = ReaderBloc(
      bookRepository: books,
      highlightRepository: FakeHighlightRepository(),
      initialSource: book,
    );
    addTearDown(bloc.close);
    deleted = [];
    bloc.add(ReaderSourceLoadRequested(sourceId: book.id));
    await bloc.stream
        .firstWhere((s) => s.bookmarks.length == 2)
        .timeout(const Duration(seconds: 3));
  }

  Future<void> pump(
    WidgetTester tester, {
    bool rtl = false,
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
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
                  // The production flow: ReaderScreen dispatches this event.
                  onBookmarkDeleted: (b) {
                    deleted.add(b);
                    bloc.add(
                      ReaderBookmarkDeleted(sourceId: b.sourceId, id: b.id),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    await tester.tap(find.text(l10n.readerBookmarks));
    await tester.pumpAndSettle();
  }

  ReadflexLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold)).l10n;

  Finder row(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(ListTile));

  Finder list() => find.ancestor(
    of: find.text('First page'),
    matching: find.byType(ListView),
  );

  Future<void> swipe(WidgetTester tester, String text, {bool rtl = false}) =>
      tester.drag(find.text(text), Offset(rtl ? 390 : -390, 0));

  testWidgets('rows show text and location without icons or buttons', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final context = tester.element(find.byType(Scaffold));
    for (final icon in [AppIcons.bookmark, AppIcons.delete]) {
      expect(
        find.descendant(of: list(), matching: find.byIcon(icon)),
        findsNothing,
      );
    }
    expect(
      find.descendant(of: list(), matching: find.byType(IconButton)),
      findsNothing,
    );
    final title = tester.widget<Text>(find.text('First page'));
    expect(title.maxLines, 2);
    expect(title.style?.fontSize, context.text.bodyMedium.fontSize);
    expect(title.style?.color, context.colors.onSurface);
    final location = tester.widget<Text>(find.text('Chapter · 10%'));
    expect(location.style?.fontSize, context.text.bodySmall.fontSize);
    expect(location.style?.color, context.colors.onSurfaceVariant);
  });

  for (final rtl in [false, true]) {
    testWidgets('390dp rows keep text on the 16dp gutters rtl=$rtl', (
      tester,
    ) async {
      await load();
      await pump(tester, rtl: rtl);
      double start(Rect rect) => rtl ? 390 - rect.right : rect.left;
      double end(Rect rect) => rtl ? rect.left : 390 - rect.right;
      final title = tester.getRect(find.text('First page'));
      final location = tester.getRect(find.text('Chapter · 10%'));
      expect(start(title), AppSpacing.lg);
      expect(start(location), AppSpacing.lg);
      expect(end(title), AppSpacing.lg);
      final rowRect = tester.getRect(row('First page'));
      expect(rowRect.left, 0);
      expect(rowRect.right, 390);
      expect(rowRect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));

      // The removed row's Undo glyph lands on the same trailing gutter.
      await swipe(tester, 'First page', rtl: rtl);
      await tester.pumpAndSettle();
      final undo = find.byTooltip(l10nOf(tester).commonUndo);
      expect(tester.getSize(undo), const Size.square(AppSizes.buttonHeight));
      expect(end(tester.getRect(find.byIcon(AppIcons.undo))), AppSpacing.lg);
      expect(start(tester.getRect(find.text('First page'))), AppSpacing.lg);
    });

    testWidgets('a swipe reveals the full-bleed delete fill rtl=$rtl', (
      tester,
    ) async {
      await load();
      await pump(tester, rtl: rtl);
      final rowRect = tester.getRect(row('First page'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('First page')),
      );
      final direction = rtl ? 1.0 : -1.0;
      await gesture.moveBy(Offset(direction * 20, 0));
      await gesture.moveBy(Offset(direction * 120, 0));
      await tester.pump();
      final colors = tester.element(find.byType(Scaffold)).colors;
      final fill = find.ancestor(
        of: find.descendant(of: list(), matching: find.byIcon(AppIcons.delete)),
        matching: find.byType(ColoredBox),
      );
      expect(tester.widget<ColoredBox>(fill.first).color, colors.error);
      expect(tester.getRect(fill.first), rowRect);
      final glyph = tester.getRect(
        find.descendant(of: list(), matching: find.byIcon(AppIcons.delete)),
      );
      expect(glyph.size, const Size.square(AppIconSize.sm));
      expect(rtl ? glyph.left : 390 - glyph.right, AppSpacing.lg);
      final label = find.descendant(
        of: fill.first,
        matching: find.text(l10nOf(tester).readerDeleteBookmark),
      );
      expect(
        tester.widget<Text>(label).style?.color,
        colors.onError,
      );
      expect(
        rtl
            ? tester.getRect(label).left - glyph.right
            : glyph.left - tester.getRect(label).right,
        AppSpacing.sm,
      );
      // Below the threshold the row springs back and nothing is deleted.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(tester.getRect(row('First page')), rowRect);
    });

    testWidgets('a swipe deletes through the bloc and shows Undo rtl=$rtl', (
      tester,
    ) async {
      await load();
      await pump(tester, rtl: rtl);
      final l10n = l10nOf(tester);
      final restingTitle = tester.getRect(find.text('First page'));
      await swipe(tester, 'First page', rtl: rtl);
      await tester.pumpAndSettle();
      expect(deleted, [first]);
      expect(bloc.state.bookmarks, [second]);
      expect(bloc.state.bookmarkEdits.removed, [first]);
      expect(books.bookmarksBySourceId[book.id], [second]);
      // The swiped row is replaced in place by its Undo row.
      expect(find.text('First page'), findsOneWidget);
      expect(find.text(l10n.readerBookmarkRemoved), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('First page'),
          matching: find.byType(Dismissible),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.text('First page')).top,
        lessThan(tester.getRect(find.text('Second page')).top),
      );

      await tester.tap(find.byTooltip(l10n.commonUndo));
      await tester.pumpAndSettle();
      expect(bloc.state.bookmarks, [first, second]);
      expect(bloc.state.bookmarkEdits.removed, isEmpty);
      expect(find.text(l10n.readerBookmarkRemoved), findsNothing);
      expect(find.byIcon(AppIcons.undo), findsNothing);
      expect(tester.takeException(), isNull);

      // The restored row is back at rest and swipeable again.
      expect(tester.getRect(find.text('First page')), restingTitle);
      await swipe(tester, 'First page', rtl: rtl);
      await tester.pumpAndSettle();
      expect(deleted, [first, first]);
      expect(bloc.state.bookmarkEdits.removed, [first]);
    });

    testWidgets('a start-to-end drag keeps the bookmark rtl=$rtl', (
      tester,
    ) async {
      await load();
      await pump(tester, rtl: rtl);
      await tester.drag(find.text('First page'), Offset(rtl ? -390 : 390, 0));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(bloc.state.bookmarks, [first, second]);
    });
  }

  testWidgets('a semantics action deletes the bookmark like the swipe', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await load();
    await pump(tester);
    final l10n = l10nOf(tester);
    final id = CustomSemanticsAction.getIdentifier(
      CustomSemanticsAction(label: l10n.readerDeleteBookmark),
    );
    final node = tester.getSemantics(find.text('First page'));
    final data = node.getSemanticsData();
    expect(data.customSemanticsActionIds, contains(id));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.label, contains('First page'));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    node.owner!.performAction(node.id, SemanticsAction.customAction, id);
    await tester.pumpAndSettle();
    expect(deleted, [first]);
    expect(bloc.state.bookmarkEdits.removed, [first]);
    expect(find.text(l10n.readerBookmarkRemoved), findsOneWidget);
    // The removed row offers Undo instead of Delete.
    final removed = tester.getSemantics(find.text(l10n.readerBookmarkRemoved));
    expect(removed.getSemanticsData().customSemanticsActionIds ?? [], isEmpty);
    final undo = tester.getSemantics(find.byTooltip(l10n.commonUndo));
    expect(undo.getSemanticsData().tooltip, l10n.commonUndo);
    expect(undo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('a failed delete brings the row back and can be retried', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final l10n = l10nOf(tester);
    final rowRect = tester.getRect(row('First page'));
    books.shouldThrow = true;
    await swipe(tester, 'First page');
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarks, [first, second]);
    expect(bloc.state.bookmarkEdits.failedId, 'first');
    // Not left swiped aside: the row is back at rest with the failure.
    expect(tester.getRect(row('First page')).left, rowRect.left);
    expect(
      find.text('Chapter · 10% · ${l10n.readerBookmarkUpdateFailed}'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ReaderSwipeToDelete>(
            find.ancestor(
              of: find.text('First page'),
              matching: find.byType(ReaderSwipeToDelete),
            ),
          )
          .onDelete,
      isNotNull,
    );

    // A second failure in a row also leaves an ordinary row at rest.
    await swipe(tester, 'First page');
    await tester.pumpAndSettle();
    expect(deleted, [first, first]);
    expect(bloc.state.bookmarkEdits.failedId, 'first');
    expect(tester.getRect(row('First page')).left, rowRect.left);
    expect(
      find
          .descendant(of: list(), matching: find.byIcon(AppIcons.delete))
          .hitTestable(),
      findsNothing,
    );

    books.shouldThrow = false;
    await swipe(tester, 'First page');
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarkEdits.removed, [first]);
    expect(find.text(l10n.readerBookmarkRemoved), findsOneWidget);
  });

  testWidgets('a swipe queued behind another write still deletes', (
    tester,
  ) async {
    await load();
    await pump(tester);
    final l10n = l10nOf(tester);
    await swipe(tester, 'First page');
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    books.restoreGate = gate.future;
    await tester.tap(find.byTooltip(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarkEdits.busyId, 'first');
    final secondRow = tester.getRect(row('Second page'));
    await swipe(tester, 'Second page');
    await tester.pumpAndSettle();
    expect(deleted, [first, second]);
    // Queued behind the restore: the row waits at rest, not swiped aside.
    expect(tester.getRect(row('Second page')), secondRow);
    expect(bloc.state.bookmarks.map((b) => b.id), ['second']);
    gate.complete();
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarks, [first]);
    expect(bloc.state.bookmarkEdits.removed, [second]);
    expect(tester.takeException(), isNull);
  });

  for (final rtl in [false, true]) {
    testWidgets('large text keeps rows and the swipe fill in bounds rtl=$rtl', (
      tester,
    ) async {
      await load();
      await pump(tester, rtl: rtl, scale: 2);
      expect(tester.takeException(), isNull);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('First page')),
      );
      await gesture.moveBy(Offset(rtl ? 20 : -20, 0));
      await gesture.moveBy(Offset(rtl ? 140 : -140, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pumpAndSettle();
      await swipe(tester, 'First page', rtl: rtl);
      await tester.pumpAndSettle();
      final undo = find.byTooltip(l10nOf(tester).commonUndo);
      expect(tester.getSize(undo), const Size.square(AppSizes.buttonHeight));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('swipe keys are stable per bookmark id', (tester) async {
    await load();
    await pump(tester);
    Key? keyOf(String text) => tester
        .widget<Dismissible>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(Dismissible),
          ),
        )
        .key;
    expect(keyOf('First page'), const ValueKey<Object>('first'));
    expect(keyOf('Second page'), const ValueKey<Object>('second'));
    // A failed delete keeps the same key: the swipe already sprang back.
    books.shouldThrow = true;
    await swipe(tester, 'First page');
    await tester.pumpAndSettle();
    expect(bloc.state.bookmarkEdits.failedId, 'first');
    expect(keyOf('First page'), const ValueKey<Object>('first'));
  });
}
