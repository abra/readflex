import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_title_layout.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

LibrarySource _book(String id) => LibrarySource.fromBook(
  Book(
    id: id,
    title: 'Book $id',
    filePath: '/$id.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  ),
);

final _title = find.byKey(const ValueKey('libraryHeaderTitle'));
final _displayButton = find.byKey(const ValueKey('libraryHeaderDisplayButton'));
final _stackedTitle = find.byKey(const ValueKey('libraryHeaderStackedTitle'));

void main() {
  // Real title metrics: whether the title shares the action row is decided by
  // measuring Literata, which the square test font distorts.
  setUpAll(() async {
    await (FontLoader('Literata')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Literata-Variable.ttf',
          ),
        ))
        .load();
  });

  Future<ReadflexLocalizations> pumpHeader(
    WidgetTester tester, {
    LibraryState? state,
    double width = 390,
    double textScale = 1,
    Locale locale = const Locale('en'),
    ThemeData? theme,
    bool isOffline = false,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: LibraryHeader(
            state: state ?? LibraryState(),
            isOffline: isOffline,
            searchController: controller,
            searchFocusNode: focus,
            onSearchChanged: (_) {},
          ),
        ),
      ),
    );
    return tester.element(find.byType(LibraryHeader)).l10n;
  }

  Finder titleText(String title) =>
      find.descendant(of: _title, matching: find.text(title));

  group('header geometry', () {
    testWidgets('no count pill, collection pill or filter chips: the '
        'Collections picker chooses what the Library shows', (tester) async {
      final strings = await pumpHeader(
        tester,
        state: LibraryState(
          sources: [_book('a')],
          collectionScopes: [LibraryCollectionScope.favourites()],
          selectedCollectionScope: LibraryCollectionScope.favourites(),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(
        find.byKey(const ValueKey('library-collection-fill')),
        findsNothing,
      );
      expect(find.byIcon(AppIcons.collection), findsNothing);
      expect(find.byIcon(AppIcons.collectionFavourites), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(AppFilterChip), findsNothing);
      for (final label in [
        strings.libraryScopeBooks,
        strings.libraryScopeArticles,
        strings.libraryScopeComics,
        strings.libraryScopeNew,
      ]) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('subtitle counts the whole library without a scope', (
      tester,
    ) async {
      final sources = [_book('a'), _book('b'), _book('c')];
      final strings = await pumpHeader(
        tester,
        state: LibraryState(
          sources: sources,
          // Search narrows the list, not the scope count.
          searchQuery: 'Book a',
        ),
      );
      final subtitle = find.byKey(const ValueKey('libraryHeaderItemCount'));
      expect(tester.widget<Text>(subtitle).data, strings.libraryItemCount(3));
      expect(find.text('3 items'), findsOneWidget);
    });

    testWidgets('an empty library has no item count subtitle', (
      tester,
    ) async {
      await pumpHeader(tester, state: LibraryState(sources: const []));
      expect(
        find.byKey(const ValueKey('libraryHeaderItemCount')),
        findsNothing,
      );
      expect(find.text('0 items'), findsNothing);
    });

    testWidgets('an empty collection still counts zero items', (tester) async {
      final scope = LibraryCollectionScope.favourites();
      final strings = await pumpHeader(
        tester,
        state: LibraryState(
          sources: [_book('a')],
          collectionScopes: [scope],
          selectedCollectionScope: scope,
        ),
      );
      expect(find.text(strings.libraryItemCount(0)), findsOneWidget);
    });

    testWidgets('subtitle counts the selected collection', (tester) async {
      final scope = LibraryCollectionScope.favourites(sourceIds: ['a']);
      final strings = await pumpHeader(
        tester,
        state: LibraryState(
          sources: [_book('a'), _book('b'), _book('c')],
          collectionScopes: [scope],
          selectedCollectionScope: scope,
        ),
      );
      expect(find.text(strings.libraryItemCount(1)), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
    });

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('subtitle is muted bodySmall under the title on the gutter: '
          '${theme.brightness}', (tester) async {
        final strings = await pumpHeader(
          tester,
          theme: theme,
          state: LibraryState(sources: [_book('a')]),
        );
        final subtitle = find.text(strings.libraryItemCount(1));
        final style = tester.widget<Text>(subtitle).style!;
        expect(style.fontSize, theme.textTheme.bodySmall!.fontSize);
        expect(style.color, theme.colorScheme.onSurfaceVariant);
        final a = style.color!.computeLuminance() + .05;
        final b = theme.scaffoldBackgroundColor.computeLuminance() + .05;
        expect(a > b ? a / b : b / a, greaterThanOrEqualTo(4.5));
        final subtitleRect = tester.getRect(subtitle);
        final title = tester.getRect(titleText(strings.libraryTitle));
        expect(subtitleRect.left, AppSpacing.lg);
        expect(subtitleRect.left, title.left);
        expect(subtitleRect.top, greaterThanOrEqualTo(title.bottom));
        // Directly under the title row, which the 48dp Display target sets.
        expect(
          subtitleRect.top,
          closeTo(tester.getRect(_displayButton).bottom, .01),
        );
        expect(
          tester.getRect(find.byType(SearchField)).top - subtitleRect.bottom,
          closeTo(AppSpacing.lg, .01),
        );
      });
    }

    testWidgets('the header has no add action; "+" lives at the bottom', (
      tester,
    ) async {
      final strings = await pumpHeader(tester);
      expect(find.byIcon(AppIcons.add), findsNothing);
      expect(find.byTooltip(strings.importAddToLibraryTitle), findsNothing);
      expect(
        find.byKey(const ValueKey('libraryHeaderAddButton')),
        findsNothing,
      );
    });

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('"⋮" is the only action; its glyph ends on the 16dp gutter '
          '($locale)', (tester) async {
        final strings = await pumpHeader(
          tester,
          locale: locale,
          isOffline: true,
        );
        final rtl = locale.languageCode == 'ar';
        final display = tester.getRect(_displayButton);
        final displayGlyph = tester.getRect(
          find.descendant(
            of: _displayButton,
            matching: find.byIcon(AppIcons.moreVertical),
          ),
        );
        final search = tester.getRect(find.byType(SearchField));
        final title = tester.getRect(titleText(strings.libraryTitle));
        final offline = tester.getRect(find.byIcon(AppIcons.offline));

        expect(display.size, const Size.square(48));
        expect(search.left, AppSpacing.lg);
        expect(search.right, 390 - AppSpacing.lg);
        if (rtl) {
          expect(displayGlyph.left, closeTo(AppSpacing.lg, .01));
          expect(title.right, closeTo(390 - AppSpacing.lg, .01));
          expect(offline.right, lessThan(title.left));
          expect(offline.left, greaterThan(display.right));
        } else {
          expect(displayGlyph.right, closeTo(390 - AppSpacing.lg, .01));
          expect(
            display.right,
            closeTo(390 - AppSpacing.lg + AppSizes.iconActionOutset, .01),
          );
          expect(title.left, closeTo(AppSpacing.lg, .01));
          expect(offline.left, greaterThan(title.right));
          expect(offline.right, lessThan(display.left));
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('muted header glyphs use onSurfaceVariant: '
          '${theme.brightness}', (tester) async {
        await pumpHeader(tester, theme: theme);
        final colors = theme.colorScheme;
        expect(
          tester.widget<AppPlainIconButton>(_displayButton).color,
          colors.onSurfaceVariant,
        );
      });
    }

    testWidgets('header targets meet tap-target guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpHeader(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });
  });

  group('title', () {
    testWidgets('shows Library without a scope', (tester) async {
      final strings = await pumpHeader(tester);
      expect(titleText(strings.libraryTitle), findsOneWidget);
      final style = tester.widget<Text>(titleText(strings.libraryTitle)).style!;
      final theme = Theme.of(tester.element(_title));
      expect(style.fontFamily, theme.textTheme.headlineMedium!.fontFamily);
      expect(style.fontSize, theme.textTheme.headlineMedium!.fontSize);
    });

    for (final (name, scope, label) in [
      (
        'favourites',
        LibraryCollectionScope.favourites(sourceIds: ['a']),
        // The full localized name, not the old badge abbreviation.
        'Favourites',
      ),
      (
        'manual',
        LibraryCollectionScope.manual(
          collection: LibraryCollection(
            id: 'reading',
            name: 'Reading list',
            sourceCount: 1,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          sourceIds: const ['a'],
        ),
        'Reading list',
      ),
      (
        'author',
        const LibraryCollectionScope.smart(
          type: LibraryCollectionScopeType.author,
          id: 'author:ada',
          label: 'Ada Lovelace',
          sourceCount: 1,
        ),
        'Ada Lovelace',
      ),
    ]) {
      testWidgets('shows the selected scope label: $name', (tester) async {
        final strings = await pumpHeader(
          tester,
          state: LibraryState(
            sources: [_book('a')],
            collectionScopes: [scope],
            selectedCollectionScope: scope,
          ),
        );
        expect(titleText(label), findsOneWidget);
        expect(find.text(strings.libraryTitle), findsNothing);
      });
    }

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('is a heading, not a control: no tap action, no chevron '
          '($locale)', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final scope = LibraryCollectionScope.favourites();
          final strings = await pumpHeader(
            tester,
            locale: locale,
            state: LibraryState(
              collectionScopes: [scope],
              selectedCollectionScope: scope,
            ),
          );
          final data = tester.getSemantics(_title).getSemanticsData();
          expect(data.label, strings.libraryFavourites);
          expect(data.flagsCollection.isHeader, isTrue);
          expect(data.flagsCollection.isButton, isFalse);
          expect(data.hasAction(SemanticsAction.tap), isFalse);
          expect(
            find.bySemanticsLabel(strings.libraryChooseCollection),
            findsNothing,
          );
          expect(find.byIcon(AppIcons.chevronDown), findsNothing);
          expect(
            find.ancestor(of: _title, matching: find.byType(InkWell)),
            findsNothing,
          );
          // The text itself sits on the 16dp gutter, with no ink inset.
          final rtl = locale.languageCode == 'ar';
          final title = tester.getRect(titleText(strings.libraryFavourites));
          if (rtl) {
            expect(title.right, closeTo(390 - AppSpacing.lg, .01));
          } else {
            expect(title.left, closeTo(AppSpacing.lg, .01));
          }
        } finally {
          semantics.dispose();
        }
      });
    }
  });

  group('large text', () {
    testWidgets('normal scale at 320dp keeps title and actions on one row', (
      tester,
    ) async {
      final strings = await pumpHeader(tester, width: 320);
      expect(_stackedTitle, findsNothing);
      final title = tester.getRect(titleText(strings.libraryTitle));
      final display = tester.getRect(_displayButton);
      expect(title.center.dy, closeTo(display.center.dy, 1));
      expect(title.left, closeTo(AppSpacing.lg, .01));
      final paragraph = tester.renderObject<RenderParagraph>(
        titleText(strings.libraryTitle),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.widget<Text>(titleText(strings.libraryTitle)).maxLines,
        1,
      );
    });

    testWidgets('2.0 scale at 320dp keeps Library on the action row: the '
        'title carries no chevron or ink inset', (tester) async {
      final strings = await pumpHeader(tester, width: 320, textScale: 2);
      expect(_stackedTitle, findsNothing);
      final titleFinder = titleText(strings.libraryTitle);
      final title = tester.getRect(titleFinder);
      expect(title.left, closeTo(AppSpacing.lg, .01));
      expect(
        title.center.dy,
        closeTo(tester.getRect(_displayButton).center.dy, 1),
      );
      expect(
        tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('2.0 scale at 320dp stacks actions above an unclipped title '
          '($locale)', (tester) async {
        const name = 'Reading list';
        final scope = LibraryCollectionScope.manual(
          collection: LibraryCollection(
            id: 'reading',
            name: name,
            sourceCount: 0,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          sourceIds: const [],
        );
        await pumpHeader(
          tester,
          width: 320,
          textScale: 2,
          locale: locale,
          state: LibraryState(
            collectionScopes: [scope],
            selectedCollectionScope: scope,
          ),
        );
        final rtl = locale.languageCode == 'ar';
        expect(_stackedTitle, findsOneWidget);
        final titleFinder = titleText(name);
        final title = tester.getRect(titleFinder);
        final display = tester.getRect(_displayButton);
        final displayGlyph = tester.getRect(
          find.descendant(
            of: _displayButton,
            matching: find.byIcon(AppIcons.moreVertical),
          ),
        );
        expect(display.bottom, lessThanOrEqualTo(title.top));
        if (rtl) {
          expect(displayGlyph.left, closeTo(AppSpacing.lg, .01));
          expect(title.right, closeTo(320 - AppSpacing.lg, .01));
          expect(
            tester.getRect(find.byIcon(AppIcons.offline)).left,
            greaterThanOrEqualTo(AppSpacing.lg - .01),
          );
        } else {
          expect(displayGlyph.right, closeTo(320 - AppSpacing.lg, .01));
          expect(title.left, closeTo(AppSpacing.lg, .01));
          expect(
            tester.getRect(find.byIcon(AppIcons.offline)).right,
            lessThanOrEqualTo(320 - AppSpacing.lg + .01),
          );
        }
        final text = tester.widget<Text>(titleFinder);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.maxLines, 2);
        final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
        expect(paragraph.didExceedMaxLines, isFalse);
        // Each word fits, so the role size is kept.
        final theme = Theme.of(tester.element(titleFinder));
        expect(text.style!.fontSize, theme.textTheme.headlineMedium!.fontSize);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a word wider than the stacked row shrinks to fit', (
      tester,
    ) async {
      const word = 'Bibliothek';
      final scope = LibraryCollectionScope.manual(
        collection: LibraryCollection(
          id: 'word',
          name: word,
          sourceCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        sourceIds: const [],
      );
      await pumpHeader(
        tester,
        width: 320,
        textScale: 2,
        state: LibraryState(
          collectionScopes: [scope],
          selectedCollectionScope: scope,
        ),
      );
      final titleFinder = titleText(word);
      final text = tester.widget<Text>(titleFinder);
      final role = Theme.of(
        tester.element(titleFinder),
      ).textTheme.headlineMedium!;
      // Precondition: at the role size the word overflows the title slot.
      final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
      final slotWidth = paragraph.constraints.maxWidth;
      final full = TextPainter(
        text: TextSpan(text: word, style: role),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2),
      )..layout();
      addTearDown(full.dispose);
      expect(full.width, greaterThan(slotWidth));
      expect(full.width * kLibraryTitleMinFontScale, lessThan(slotWidth));

      expect(text.style!.fontSize, lessThan(role.fontSize!));
      expect(
        text.style!.fontSize,
        greaterThanOrEqualTo(role.fontSize! * kLibraryTitleMinFontScale - .01),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      // The word is not broken: one line.
      final scaled = TextPainter(
        text: TextSpan(text: word, style: text.style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2),
      )..layout(maxWidth: slotWidth);
      addTearDown(scaled.dispose);
      expect(scaled.computeLineMetrics(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long multi-word collection name wraps without an ellipsis', (
      tester,
    ) async {
      const name = 'Essays on the history of reading machines';
      final scope = LibraryCollectionScope.manual(
        collection: LibraryCollection(
          id: 'long',
          name: name,
          sourceCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        sourceIds: const [],
      );
      await pumpHeader(
        tester,
        width: 320,
        textScale: 2,
        state: LibraryState(
          collectionScopes: [scope],
          selectedCollectionScope: scope,
        ),
      );
      final titleFinder = titleText(name);
      expect(_stackedTitle, findsOneWidget);
      final text = tester.widget<Text>(titleFinder);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getRect(titleFinder).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });

  group('resolveLibraryTitleLayout', () {
    // The square test font: every glyph is one em wide.
    const style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10);

    LibraryTitleLayout resolve(
      String title, {
      required double inline,
      required double stacked,
    }) => resolveLibraryTitleLayout(
      title: title,
      style: style,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
      inlineWidth: inline,
      stackedWidth: stacked,
    );

    test('stays inline when the title fits beside the actions', () {
      final layout = resolve('abc', inline: 30, stacked: 100);
      expect(layout.stacked, isFalse);
      expect(layout.fontScale, 1);
      expect(layout.maxLines, 1);
    });

    test('stacks at full size when every word fits', () {
      final layout = resolve('abc def', inline: 50, stacked: 100);
      expect(layout.stacked, isTrue);
      expect(layout.fontScale, 1);
      expect(layout.maxLines, 2);
    });

    test('shrinks a single word that is wider than the row', () {
      final layout = resolve('abcdefghij', inline: 50, stacked: 80);
      expect(layout.stacked, isTrue);
      expect(layout.fontScale, closeTo(.8, .051));
      expect(layout.fontScale, lessThan(1));
      expect(layout.maxLines, 2);
    });

    test('never shrinks below the minimum', () {
      final layout = resolve('abcdefghijklmnopqrst', inline: 50, stacked: 80);
      expect(layout.stacked, isTrue);
      expect(layout.fontScale, kLibraryTitleMinFontScale);
    });

    test('wraps past two lines rather than truncate at the minimum', () {
      final layout = resolve(
        'ab ab ab ab ab ab ab ab',
        inline: 20,
        stacked: 50,
      );
      expect(layout.stacked, isTrue);
      expect(layout.fontScale, kLibraryTitleMinFontScale);
      expect(layout.maxLines, isNull);
    });

    test('libraryTitleStyle scales only the font size', () {
      final scaled = libraryTitleStyle(style, .5);
      expect(scaled.fontSize, 5);
      expect(scaled.fontFamily, style.fontFamily);
      expect(identical(libraryTitleStyle(style, 1), style), isTrue);
    });
  });
}
