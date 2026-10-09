import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_body.dart';
import 'package:library_feature/src/library_empty_state.dart';
import 'package:library_feature/src/library_import_entry.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  final book = LibrarySource.fromBook(
    Book(
      id: 'b-1',
      title: 'First',
      filePath: '/b1.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
    ),
  );

  Future<ReadflexLocalizations> pumpBody(
    WidgetTester tester,
    LibraryState state, {
    ValueChanged<LibraryImportEntry>? onImportPressed,
    VoidCallback? onClearSearch,
    VoidCallback? onShowWholeLibrary,
    bool importEnabled = true,
    double textScale = 2,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: LibraryBody(
            state: state,
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
            onImportPressed: importEnabled ? onImportPressed ?? (_) {} : null,
            onRefresh: () async {},
            onClearSearch: onClearSearch ?? () {},
            onShowWholeLibrary: onShowWholeLibrary ?? () {},
          ),
        ),
      ),
    );
    return tester.element(find.byType(LibraryBody)).l10n;
  }

  final uploadButton = find.byKey(const ValueKey('libraryEmptyUploadFile'));
  final articleButton = find.byKey(const ValueKey('libraryEmptySaveArticle'));

  testWidgets('empty library state applies the 16dp gutter once', (
    tester,
  ) async {
    final strings = await pumpBody(tester, LibraryState());
    expect(find.byType(LibraryEmptyState), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(LibraryEmptyState),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
    // Large text wraps the subtitle so it spans the padded width.
    final subtitle = tester.getRect(find.text(strings.libraryEmptySubtitle));
    expect(subtitle.left, AppSpacing.lg);
    expect(subtitle.right, 320 - AppSpacing.lg);
    for (final button in [uploadButton, articleButton]) {
      final rect = tester.getRect(button);
      expect(rect.left, AppSpacing.lg);
      expect(rect.right, 320 - AppSpacing.lg);
    }
    expect(
      tester.getSize(find.byType(ConstrainedBox).first).height,
      greaterThanOrEqualTo(568 * 0.6),
    );
    expect(tester.takeException(), isNull);
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('empty library: tinted icon, serif title, two stacked '
        'commands and the file kinds (${theme.brightness})', (tester) async {
      final strings = await pumpBody(
        tester,
        LibraryState(),
        textScale: 1,
        theme: theme,
      );
      final frame = find.byKey(const ValueKey('libraryEmptyIconFrame'));
      expect(tester.getSize(frame), const Size.square(72));
      final context = tester.element(frame);
      final decoration =
          tester.widget<Container>(frame).decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color!.a, lessThan(.5));
      expect(decoration.color!.withValues(alpha: 1), context.actionForeground);
      expect(
        find.descendant(of: frame, matching: find.byIcon(AppIcons.book)),
        findsOneWidget,
      );

      final title = tester.widget<Text>(find.text(strings.libraryEmptyTitle));
      expect(
        title.style!.fontFamily,
        theme.textTheme.headlineSmall!.fontFamily,
      );
      expect(title.style!.fontSize, theme.textTheme.headlineSmall!.fontSize);
      expect(find.text(strings.libraryEmptySubtitle), findsOneWidget);

      expect(
        find.descendant(
          of: uploadButton,
          matching: find.text(strings.libraryUploadFile),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: uploadButton,
          matching: find.byIcon(AppIcons.uploadFile),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: articleButton,
          matching: find.text(strings.librarySaveArticleAction),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: articleButton,
          matching: find.byIcon(AppIcons.link),
        ),
        findsOneWidget,
      );
      expect(tester.widget(uploadButton), isA<FilledButton>());
      expect(tester.widget(articleButton), isA<OutlinedButton>());

      final upload = tester.getRect(uploadButton);
      final article = tester.getRect(articleButton);
      final caption = tester.getRect(find.text(strings.importFileKinds));
      expect(article.top - upload.bottom, closeTo(10, .01));
      expect(upload.width, article.width);
      expect(caption.top, greaterThan(article.bottom));
      expect(
        tester.widget<Text>(find.text(strings.importFileKinds)).style!.color,
        theme.colorScheme.onSurfaceVariant,
      );
      expect(
        tester.getRect(frame).bottom,
        lessThan(tester.getRect(find.text(strings.libraryEmptyTitle)).top),
      );
    });
  }

  testWidgets('empty library commands pass their import entry', (
    tester,
  ) async {
    final entries = <LibraryImportEntry>[];
    await pumpBody(tester, LibraryState(), onImportPressed: entries.add);
    await tester.ensureVisible(uploadButton);
    await tester.tap(uploadButton);
    await tester.ensureVisible(articleButton);
    await tester.tap(articleButton);
    expect(entries, [LibraryImportEntry.file, LibraryImportEntry.article]);
  });

  testWidgets('empty library commands disable without a callback', (
    tester,
  ) async {
    await pumpBody(tester, LibraryState(), importEnabled: false);
    expect(tester.widget<FilledButton>(uploadButton).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(articleButton).onPressed, isNull);
  });

  testWidgets('filtered-out state applies the 16dp gutter once', (
    tester,
  ) async {
    final strings = await pumpBody(
      tester,
      LibraryState(sources: [book], searchQuery: 'nothing matches'),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    // Only the scroll view's bottom clearance for "+" wraps it; no second
    // horizontal gutter.
    for (final padding in tester.widgetList<Padding>(
      find.ancestor(
        of: find.byType(EmptyState),
        matching: find.byType(Padding),
      ),
    )) {
      expect(padding.padding.horizontal, 0);
    }
    final subtitle = tester.getRect(
      find.text(strings.libraryNoResultsSubtitle),
    );
    expect(subtitle.left, AppSpacing.lg);
    expect(subtitle.right, 320 - AppSpacing.lg);
    expect(
      find.widgetWithText(TextButton, strings.commonClearSearch),
      findsOneWidget,
    );
  });

  group('nothing listed in a non-empty library', () {
    final clearSearch = find.byKey(const ValueKey('libraryClearSearchButton'));
    final showWholeLibrary = find.byKey(
      const ValueKey('libraryShowWholeLibraryButton'),
    );
    final favourites = LibraryCollectionScope.favourites();

    testWidgets('a search without matches offers to clear the search, not '
        'filters', (tester) async {
      var cleared = 0;
      var shownAll = 0;
      final strings = await pumpBody(
        tester,
        LibraryState(sources: [book], searchQuery: 'nothing matches'),
        textScale: 1,
        onClearSearch: () => cleared++,
        onShowWholeLibrary: () => shownAll++,
      );
      expect(find.text(strings.libraryNoResultsTitle), findsOneWidget);
      expect(find.text(strings.libraryNoResultsSubtitle), findsOneWidget);
      expect(find.byIcon(AppIcons.searchOff), findsOneWidget);
      expect(showWholeLibrary, findsNothing);
      expect(
        find.descendant(
          of: clearSearch,
          matching: find.text(strings.commonClearSearch),
        ),
        findsOneWidget,
      );
      await tester.tap(clearSearch);
      expect(cleared, 1);
      expect(shownAll, 0);
    });

    testWidgets('a search inside a collection still clears only the search', (
      tester,
    ) async {
      final strings = await pumpBody(
        tester,
        LibraryState(
          sources: [book],
          searchQuery: 'nothing matches',
          selectedCollectionScope: favourites,
        ),
        textScale: 1,
      );
      expect(find.text(strings.libraryNoResultsTitle), findsOneWidget);
      expect(clearSearch, findsOneWidget);
      expect(showWholeLibrary, findsNothing);
    });

    testWidgets('an empty collection says so and leads back to the whole '
        'Library', (tester) async {
      var cleared = 0;
      var shownAll = 0;
      final strings = await pumpBody(
        tester,
        LibraryState(sources: [book], selectedCollectionScope: favourites),
        textScale: 1,
        onClearSearch: () => cleared++,
        onShowWholeLibrary: () => shownAll++,
      );
      expect(find.text(strings.libraryEmptyCollectionTitle), findsOneWidget);
      expect(find.text(strings.libraryNoResultsTitle), findsNothing);
      expect(find.text(strings.libraryNoResultsSubtitle), findsNothing);
      // The collection's own glyph, as on its picker row.
      expect(find.byIcon(AppIcons.collectionFavourites), findsOneWidget);
      expect(clearSearch, findsNothing);
      expect(
        find.descendant(
          of: showWholeLibrary,
          matching: find.text(strings.libraryShowWholeLibrary),
        ),
        findsOneWidget,
      );
      await tester.tap(showWholeLibrary);
      expect(shownAll, 1);
      expect(cleared, 0);
    });

    for (final state in [
      LibraryState(sources: [book], searchQuery: 'nothing matches'),
      LibraryState(sources: [book], selectedCollectionScope: favourites),
    ]) {
      testWidgets('the command scrolls clear of the "+" button: '
          '${state.searchQuery.isEmpty ? 'empty collection' : 'search'}', (
        tester,
      ) async {
        await pumpBody(tester, state);
        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scroll.padding,
          EdgeInsets.only(
            bottom: libraryContentBottomPadding(
              tester.element(find.byType(EmptyState)),
            ),
          ),
        );
      });
    }
  });

  testWidgets('an empty library has no "+" to clear', (tester) async {
    await pumpBody(tester, LibraryState(sources: const []));
    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding,
      isNull,
    );
  });
}
