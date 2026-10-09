import 'dart:async';
import 'dart:math' as math;

import 'package:article_repository/article_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_body.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:library_feature/src/library_grid_tile.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_selection_bar.dart';
import 'package:library_feature/src/library_language_sheet.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';

const double _collectionSourcesMaxHeightForTest = 260;

final _addButton = find.byKey(const ValueKey('libraryAddButton'));
final _collectionsButton = find.byKey(
  const ValueKey('libraryCollectionsButton'),
);
final _capsule = find.byKey(const ValueKey('libraryFloatingActions'));

/// Opens the Collections picker from the bottom capsule once the Scaffold's
/// entrance scale has settled; mid-scale the capsule is not hit-testable.
Future<void> _openCollections(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(_collectionsButton);
  await tester.pumpAndSettle();
}

/// [text] inside the header; the capsule repeats the collection name.
Finder _headerText(String text) =>
    find.descendant(of: find.byType(LibraryHeader), matching: find.text(text));

/// The colour a capsule label is painted with.
Color? _labelColor(WidgetTester tester, String label) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: _collectionsButton, matching: find.text(label)),
    )
    .text
    .style
    ?.color;

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  author: 'Eric Windmill',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

final _comicBook = Book(
  id: 'c-1',
  title: 'Panel Studies',
  filePath: '/books/panels.cbz',
  format: BookFormat.cbz,
  addedAt: DateTime(2026, 1, 3),
);

Finder _builtInRow(LibraryCollectionScopeType type) =>
    find.byKey(ValueKey('collectionScopeRow-${type.name}-${type.name}'));

final _secondBook = Book(
  id: 'b-2',
  title: 'Clean Architecture',
  author: 'Robert C. Martin',
  filePath: '/books/clean-architecture.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 2),
);

/// More rows than a phone shows, so the list scrolls.
final _longList = [
  for (var i = 0; i < 12; i++)
    Book(
      id: 'long-$i',
      title: 'Long list book $i',
      filePath: '/books/long-$i.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 1 + i),
    ),
];

void main() {
  late FakeBookRepository bookRepository;
  late FakeCollectionRepository collectionRepository;
  late PreferencesService preferencesService;

  setUp(() async {
    bookRepository = FakeBookRepository();
    collectionRepository = FakeCollectionRepository();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
  });

  Widget buildSubject({
    ArticleRepository? articleRepository,
    ThemeData? theme,
    bool isOffline = false,
    bool openImportOnStart = false,
    LibraryImportLauncher? onAddPressed,
    ValueChanged<LibrarySource>? onSourcePressed,
  }) => PreferencesScope(
    service: preferencesService,
    child: Builder(
      builder: (context) => MaterialApp(
        locale: PreferencesScope.localeOf(context),
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: theme ?? AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          articleRepository: articleRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          isOffline: isOffline,
          openImportOnStart: openImportOnStart,
          onSourcePressed: (source, {onSourceOpened}) async =>
              onSourcePressed?.call(source),
          onAddPressed:
              onAddPressed ??
              ({required onImported, entry = LibraryImportEntry.menu}) async {},
        ),
      ),
    ),
  );

  testWidgets('selection count and explicit cancel do not reload storage', (
    tester,
  ) async {
    bookRepository.seedBooks([_book, _secondBook]);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.longPress(find.text(_book.title));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
    expect(_addButton, findsNothing);
    await tester.ensureVisible(find.text(_secondBook.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_secondBook.title));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsNothing);
    expect(_addButton, findsOneWidget);
    expect(bookRepository.getBooksCallCount, 1);
  });

  testWidgets('large dark display rows and language keep readable selection', (
    tester,
  ) async {
    // Narrow 320px layouts are covered by the root goldens with real fonts.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final theme = AppTheme.dark();
    await tester.pumpWidget(buildSubject(theme: theme));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Display options'));
    await tester.pumpAndSettle();

    for (final label in ['Grid', 'System']) {
      final element = tester.element(find.text(label));
      final foreground = DefaultTextStyle.of(element).style.color!;
      final material = element.findAncestorWidgetOfExactType<Material>()!;
      final background = Color.alphaBlend(
        material.color!,
        theme.colorScheme.surface,
      );
      expect(
        _contrast(foreground, background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(background, theme.colorScheme.surface),
        greaterThanOrEqualTo(3),
      );
    }
    final picker = find.byKey(const ValueKey('libraryLanguagePicker'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final option = find.byKey(const ValueKey('libraryLanguageOption-en'));
    final label = tester.widget<Text>(
      find.descendant(of: option, matching: find.byType(Text)),
    );
    final material = tester.widget<Material>(
      find.descendant(of: option, matching: find.byType(Material)),
    );
    final background = Color.alphaBlend(
      material.color!,
      theme.colorScheme.surface,
    );
    expect(
      _contrast(label.style!.color!, background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(background, theme.colorScheme.surface),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets(
    'display opens the language step and returns to settings',
    (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Display options'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('libraryLanguageOption-ru')),
        findsNothing,
      );
      final languageRow = find.byKey(const ValueKey('libraryLanguagePicker'));
      final label = find.descendant(
        of: languageRow,
        matching: find.text('Language'),
      );
      final value = find.descendant(
        of: languageRow,
        matching: find.text('English'),
      );
      final arrow = find.descendant(
        of: languageRow,
        matching: find.byIcon(AppIcons.chevronRight),
      );
      expect(
        tester.getCenter(label).dy,
        closeTo(tester.getCenter(value).dy, 1),
      );
      expect(tester.getRect(label).right, lessThan(tester.getRect(value).left));
      expect(
        tester.getRect(arrow).left - tester.getRect(value).right,
        closeTo(AppSpacing.sm, 1),
      );
      await tester.tap(find.byKey(const ValueKey('libraryLanguagePicker')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('libraryLanguageOption-ru')),
        100,
        scrollable: find.descendant(
          of: find.byType(LibraryLanguageSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('libraryLanguageOption-ru')));
      await tester.pumpAndSettle();
      expect(preferencesService.current.locale.languageCode, 'ru');
      expect(languageRow.hitTestable(), findsNothing);
      final russian = find.byKey(const ValueKey('libraryLanguageOption-ru'));
      expect(russian.hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip(tester.element(russian).l10n.commonBack));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('libraryLanguagePicker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('libraryLanguageOption-ru')),
        findsNothing,
      );
      expect(bookRepository.getBooksCallCount, 1);
    },
  );

  testWidgets('import completion refreshes after the import UI has closed', (
    tester,
  ) async {
    late VoidCallback imported;
    await tester.pumpWidget(
      buildSubject(
        onAddPressed:
            ({required onImported, entry = LibraryImportEntry.menu}) async {
              imported = onImported;
            },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload a file'));
    await tester.pumpAndSettle();
    expect(
      bookRepository.getBooksCallCount,
      1,
      reason: 'Dismissal alone does not reload',
    );
    bookRepository.seedBooks([_book]);
    imported();
    await tester.pumpAndSettle();
    expect(find.text(_book.title), findsOneWidget);
    expect(bookRepository.getBooksCallCount, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    imported();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      bookRepository.getBooksCallCount,
      2,
      reason: 'No work after Library disposal',
    );
  });

  testWidgets('shows loading indicator initially', (tester) async {
    bookRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());

    await tester.pump();
    expect(find.text('Failed to load library'), findsOneWidget);
  });

  testWidgets('shows error state on failure', (tester) async {
    bookRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Failed to load library'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows empty state when no items', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Reset filters'), findsNothing);
  });

  testWidgets('Reset filters clears the search and the collection without '
      'reloading the library', (tester) async {
    bookRepository.seedBooks([_book, _comicBook]);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await _openCollections(tester);
    await tester.tap(_builtInRow(LibraryCollectionScopeType.comics));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text(_book.title), findsWidgets);
    expect(find.text(_comicBook.title), findsWidgets);
    expect(_headerText('Library'), findsOneWidget);
    expect(find.text('Reset filters'), findsNothing);
    expect(bookRepository.getBooksCallCount, 1);
  });

  testWidgets('shows Library header and item count with content', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      bookRepository.seedBooks([_book]);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(_headerText('Library'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.bySemanticsLabel('1 item'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('library item count is a localized subtitle', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await preferencesService.update(
        (prefs) => prefs.copyWith(locale: const Locale('ru')),
      );
      bookRepository.seedBooks([_book, _secondBook]);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(_headerText('Библиотека'), findsOneWidget);
      expect(find.text('2 элемента'), findsOneWidget);
      expect(find.bySemanticsLabel('2 элемента'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('display button opens view and appearance sheet', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('libraryHeaderDisplayButton')),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.viewList), findsNothing);
    expect(find.byIcon(AppIcons.viewGrid), findsNothing);
    expect(find.byIcon(AppIcons.deviceMode), findsNothing);

    final displayAction = find.byKey(
      const ValueKey('libraryHeaderDisplayButton'),
    );
    expect(tester.widget(displayAction), isA<AppPlainIconButton>());
    expect(tester.getSize(displayAction), const Size.square(48));
    final ink = tester.widget<InkWell>(
      find.descendant(of: displayAction, matching: find.byType(InkWell)),
    );
    expect(ink.customBorder, isA<CircleBorder>());
    expect(ink.overlayColor!.resolve({WidgetState.pressed})!.a, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();

    expect(find.text('Display'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ActionBottomSheetLayout),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.libraryLayoutMode, 'list');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.themeMode, ThemeMode.dark);
    expect(find.text('Display'), findsOneWidget);
  });

  testWidgets('display sheet changes app language', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('libraryLanguagePicker')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Русский'),
      100,
      scrollable: find.descendant(
        of: find.byType(LibraryLanguageSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.locale, const Locale('ru'));
    expect(_headerText('Библиотека'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LibraryLanguageSheet),
        matching: find.text('Язык'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('libraryLanguagePicker')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('language picker uses two columns with checkmark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('libraryLanguagePicker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('libraryLanguageOption-en')),
    );

    final englishRect = tester.getRect(
      find.byKey(const ValueKey('libraryLanguageOption-en')),
    );
    final chineseRect = tester.getRect(
      find.byKey(const ValueKey('libraryLanguageOption-zh')),
    );
    final hindiRect = tester.getRect(
      find.byKey(const ValueKey('libraryLanguageOption-hi')),
    );

    expect(chineseRect.top, englishRect.top);
    expect(chineseRect.left - englishRect.right, AppSpacing.sm);
    expect(englishRect.height, greaterThanOrEqualTo(48));
    expect(hindiRect.top, englishRect.bottom);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('libraryLanguageOption-en')),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
  });

  for (final profile in [
    // Ahem's wide glyphs force a single language column on these phones.
    // Root goldens check real-font column layout and scroll reachability.
    (
      name: 'phone',
      size: const Size(390, 844),
      locale: 'en',
      scale: 1.0,
      scrolls: true,
    ),
    (
      name: 'RTL phone',
      size: const Size(390, 844),
      locale: 'ar',
      scale: 1.0,
      scrolls: true,
    ),
    (
      name: 'short phone',
      size: const Size(390, 600),
      locale: 'en',
      scale: 1.0,
      scrolls: true,
    ),
    (
      name: 'short RTL phone',
      size: const Size(390, 600),
      locale: 'ar',
      scale: 1.0,
      scrolls: true,
    ),
    (
      name: 'large text',
      size: const Size(390, 844),
      locale: 'en',
      scale: 2.0,
      scrolls: true,
    ),
    (
      name: 'tall tablet',
      size: const Size(800, 1400),
      locale: 'en',
      scale: 1.0,
      scrolls: false,
    ),
  ]) {
    testWidgets('language fades span the sheet: ${profile.name}', (
      tester,
    ) async {
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await preferencesService.update(
        (p) => p.copyWith(locale: Locale(profile.locale)),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('libraryHeaderDisplayButton')),
      );
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('libraryLanguagePicker'));
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();

      final sheet = find.byType(LibraryLanguageSheet);
      final sheetRect = tester.getRect(
        find.descendant(
          of: sheet,
          matching: find.byType(ActionBottomSheetLayout),
        ),
      );
      final list = find.descendant(
        of: sheet,
        matching: find.byType(SingleChildScrollView),
      );
      final listRect = tester.getRect(list);
      expect(listRect.left, sheetRect.left);
      expect(listRect.right, sheetRect.right);
      final listPadding = tester
          .widget<SingleChildScrollView>(list)
          .padding!
          .resolve(Directionality.of(tester.element(list)));
      // Options bleed their 8dp inset into the 24dp gutters.
      expect(listPadding.left, AppSpacing.xl - AppSpacing.sm);
      expect(listPadding.right, AppSpacing.xl - AppSpacing.sm);
      final fades = find.descendant(
        of: sheet,
        matching: find.byType(ScrollEdgeFade),
      );
      expect(fades, findsNWidgets(2));
      for (final element in fades.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, sheetRect.left);
        expect(rect.right, sheetRect.right);
      }
      void expectFades({required bool top, required bool bottom}) {
        final widgets = tester.widgetList<ScrollEdgeFade>(fades);
        expect(
          widgets.singleWhere((w) => w.edge == ScrollFadeEdge.top).visible,
          top,
        );
        expect(
          widgets.singleWhere((w) => w.edge == ScrollFadeEdge.bottom).visible,
          bottom,
        );
      }

      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      if (!profile.scrolls) {
        expect(position.maxScrollExtent, 0);
        expectFades(top: false, bottom: false);
      } else {
        expect(position.maxScrollExtent, greaterThan(0));
        expectFades(top: false, bottom: true);
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        expectFades(top: true, bottom: true);
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expectFades(top: true, bottom: false);
        position.jumpTo(0);
        await tester.pumpAndSettle();
        expectFades(top: false, bottom: true);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switches layout without mounting both scroll views', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(LibraryGridView), findsOneWidget);
    expect(find.byType(LibraryListView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('libraryHeaderDisplayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pump();

    expect(find.byType(LibraryGridView), findsNothing);
    expect(find.byType(LibraryListView), findsOneWidget);
  });

  testWidgets('header actions stay aligned to the right edge', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    final displayButton = find.byKey(
      const ValueKey('libraryHeaderDisplayButton'),
    );
    final displayButtonRect = tester.getRect(displayButton);
    final glyphRect = tester.getRect(
      find.descendant(
        of: displayButton,
        matching: find.byIcon(AppIcons.moreVertical),
      ),
    );
    final searchRect = tester.getRect(find.byType(SearchField));

    // The 48dp target bleeds into the gutter; its glyph ends on it.
    expect(displayButtonRect.size, const Size.square(48));
    expect(
      displayButtonRect.right,
      closeTo(
        scaffoldRect.right - AppSpacing.lg + AppSizes.iconActionOutset,
        1,
      ),
    );
    expect(glyphRect.right, closeTo(scaffoldRect.right - AppSpacing.lg, 1));
    expect(glyphRect.right, closeTo(searchRect.right, 1));
  });

  testWidgets('shows offline status next to Library title', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject(isOffline: true));
    await tester.pump();

    final titleRect = tester.getRect(_headerText('Library'));
    final status = find.byIcon(AppIcons.offline);
    final statusRect = tester.getRect(status);

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(statusRect.left, greaterThan(titleRect.right));
    expect(tester.widget<Icon>(status).color, AppTheme.light().ext.warning);
    expect(find.byTooltip('offline'), findsOneWidget);
    expect(status.hitTestable(), findsOneWidget);
  });

  testWidgets('hides offline status while reserving header space', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final statusVisibility = tester.widget<Visibility>(
      find.ancestor(
        of: find.byIcon(AppIcons.offline),
        matching: find.byType(Visibility),
      ),
    );

    expect(statusVisibility.visible, isFalse);
    expect(statusVisibility.maintainSize, isTrue);
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(find.byIcon(AppIcons.offline).hitTestable(), findsNothing);
  });

  testWidgets('shows search field', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search library...'), findsOneWidget);
  });

  testWidgets('source tap keeps search unfocused after reader route returns', (
    tester,
  ) async {
    var opened = false;
    final navigatorKey = GlobalKey<NavigatorState>();
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {
            opened = true;
            await navigatorKey.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Reader route')),
              ),
            );
          },
          onAddPressed:
              ({required onImported, entry = LibraryImportEntry.menu}) async {},
        ),
      ),
    );
    await tester.pump();

    final searchField = find.widgetWithText(TextField, 'Search library...');
    await tester.tap(searchField);
    await tester.pump();

    final searchEditable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    final searchFocusNode = searchEditable.focusNode;
    expect(searchFocusNode.hasFocus, isTrue);

    await tester.tap(find.text('Flutter in Action'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.text('Reader route'), findsOneWidget);
    expect(searchFocusNode.hasFocus, isFalse);
    expect(searchFocusNode.canRequestFocus, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(_headerText('Library'), findsOneWidget);
    expect(searchFocusNode.hasFocus, isFalse);
    expect(searchFocusNode.canRequestFocus, isTrue);
  });

  group('built-in collections', () {
    testWidgets('replace the filter chips: Books and Comics are picker rows', (
      tester,
    ) async {
      bookRepository.seedBooks([_book, _comicBook]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byType(AppFilterChip), findsNothing);

      await _openCollections(tester);
      final books = _builtInRow(LibraryCollectionScopeType.books);
      final comics = _builtInRow(LibraryCollectionScopeType.comics);
      expect(books, findsOneWidget);
      expect(comics, findsOneWidget);
      // No articles; and New holds everything, which Library already shows.
      expect(_builtInRow(LibraryCollectionScopeType.articles), findsNothing);
      expect(_builtInRow(LibraryCollectionScopeType.unread), findsNothing);
      // Favourites, then Library, then the built-ins.
      final library = find.byKey(const ValueKey('collectionScopeRow-library'));
      final favourites = find.byKey(
        const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
      );
      expect(
        tester.getTopLeft(library).dy,
        greaterThan(tester.getTopLeft(favourites).dy),
      );
      expect(
        tester.getTopLeft(books).dy,
        greaterThan(tester.getTopLeft(library).dy),
      );
      expect(
        tester.getTopLeft(comics).dy,
        greaterThan(tester.getTopLeft(books).dy),
      );
      // Built-ins have no manage menu.
      expect(
        find.byKey(const ValueKey('collectionScopeManage-books-books')),
        findsNothing,
      );

      await tester.tap(books);
      await tester.pumpAndSettle();
      // The title and the capsule name the collection; the comic is
      // filtered out.
      expect(
        _headerText('Books'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _collectionsButton, matching: find.text('Books')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _collectionsButton,
          matching: find.byIcon(AppIcons.book),
        ),
        findsOneWidget,
      );
      expect(find.text(_comicBook.title), findsNothing);
      expect(find.text(_book.title), findsWidgets);
      expect(
        _labelColor(tester, 'Books'),
        AppTheme.light().colorScheme.selectedControlForeground,
      );
    });

    for (final (name, books, choose) in [
      ('a single book: no built-ins', [_book], null),
      ('a mixed library: built-ins listed', [_book, _comicBook], null),
      (
        'inside Comics',
        [_book, _comicBook],
        LibraryCollectionScopeType.comics,
      ),
    ]) {
      testWidgets('Favourites is the first row, under the search field: '
          '$name', (tester) async {
        bookRepository.seedBooks(books);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        if (choose != null) {
          await _openCollections(tester);
          await tester.tap(_builtInRow(choose));
          await tester.pumpAndSettle();
        }
        await _openCollections(tester);

        final sheet = find.byType(ActionBottomSheetLayout);
        final search = tester.getRect(
          find.descendant(of: sheet, matching: find.byType(SearchField)),
        );
        final favourites = find.byKey(
          const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
        );
        expect(
          tester.getRect(favourites).top,
          closeTo(search.bottom + AppSpacing.lg, .01),
        );
        expect(
          tester
              .getRect(find.byKey(const ValueKey('collectionScopeRow-library')))
              .top,
          closeTo(tester.getRect(favourites).bottom, .01),
        );
      });
    }

    testWidgets('a picker search that misses Favourites lists Library first', (
      tester,
    ) async {
      bookRepository.seedBooks([_book, _comicBook]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      final sheet = find.byType(ActionBottomSheetLayout);
      await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        'lib',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
        ),
        findsNothing,
      );
      final search = tester.getRect(
        find.descendant(of: sheet, matching: find.byType(SearchField)),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('collectionScopeRow-library')))
            .top,
        closeTo(search.bottom + AppSpacing.lg, .01),
      );
    });

    testWidgets('New lists items never opened when some were', (tester) async {
      bookRepository.seedBooks([
        _book,
        _secondBook.copyWith(lastOpenedAt: DateTime(2026, 2)),
      ]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      final newRow = _builtInRow(LibraryCollectionScopeType.unread);
      expect(newRow, findsOneWidget);
      expect(
        find.descendant(of: newRow, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.tap(newRow);
      await tester.pumpAndSettle();
      expect(find.text('New'), findsWidgets);
      expect(find.text(_secondBook.title), findsNothing);
    });

    testWidgets('a picker search finds built-ins by their localized name', (
      tester,
    ) async {
      await preferencesService.update(
        (p) => p.copyWith(locale: const Locale('ru')),
      );
      bookRepository.seedBooks([_book, _comicBook]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(ActionBottomSheetLayout),
          matching: find.byType(TextField),
        ),
        'комик',
      );
      await tester.pumpAndSettle();
      expect(_builtInRow(LibraryCollectionScopeType.comics), findsOneWidget);
      expect(_builtInRow(LibraryCollectionScopeType.books), findsNothing);
    });
  });

  testWidgets('"+" is the filled end of the bottom capsule and opens the '
      'import menu', (tester) async {
    final entries = <LibraryImportEntry>[];
    bookRepository.seedBooks([_book]);
    await tester.pumpWidget(
      buildSubject(
        onAddPressed:
            ({required onImported, entry = LibraryImportEntry.menu}) async {
              entries.add(entry);
            },
      ),
    );
    await tester.pumpAndSettle();

    expect(_capsule, findsOneWidget);
    expect(
      find.descendant(of: _capsule, matching: _addButton),
      findsOneWidget,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).floatingActionButton,
      isNotNull,
    );
    expect(tester.widget<IconButton>(_addButton).tooltip, 'Add to Library');
    // Only one "+" on screen: the header keeps the title and Display.
    expect(find.byIcon(AppIcons.add), findsOneWidget);
    await tester.tap(_addButton);
    await tester.pumpAndSettle();
    expect(entries, [LibraryImportEntry.menu]);
  });

  for (final rtl in [false, true]) {
    testWidgets('the capsule sits in the bottom trailing corner above the '
        'home indicator, "+" at its outer end rtl=$rtl', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      if (rtl) {
        await preferencesService.update(
          (p) => p.copyWith(locale: const Locale('ar')),
        );
      }
      bookRepository.seedBooks([_book]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The Scaffold places the capsule through a transform: compare with a
      // sub-pixel tolerance.
      final capsule = tester.getRect(_capsule);
      final add = tester.getRect(_addButton);
      final collections = tester.getRect(_collectionsButton);
      expect(capsule.height, closeTo(kLibraryFloatingActionsHeight, .01));
      // Scaffold's 16dp margin over the 34dp inset, plus the 8dp lift.
      expect(
        capsule.bottom,
        closeTo(844 - 34 - AppSpacing.lg - kLibraryFloatingActionsLift, .01),
      );
      expect(add.width, closeTo(AppSizes.buttonHeight, .01));
      expect(add.height, closeTo(AppSizes.buttonHeight, .01));
      expect(collections.height, closeTo(AppSizes.buttonHeight, .01));
      expect(add.center.dy, closeTo(capsule.center.dy, .01));
      expect(collections.center.dy, closeTo(capsule.center.dy, .01));
      // Controls sit 4dp inside the capsule and 4dp apart.
      const inset = (kLibraryFloatingActionsHeight - AppSizes.buttonHeight) / 2;
      if (rtl) {
        expect(capsule.left, closeTo(AppSpacing.lg, .01));
        expect(add.left - capsule.left, closeTo(inset, .01));
        expect(collections.left - add.right, closeTo(inset, .01));
        expect(capsule.right - collections.right, closeTo(inset, .01));
      } else {
        expect(capsule.right, closeTo(390 - AppSpacing.lg, .01));
        expect(capsule.right - add.right, closeTo(inset, .01));
        expect(add.left - collections.right, closeTo(inset, .01));
        expect(collections.left - capsule.left, closeTo(inset, .01));
      }
    });
  }

  for (final dark in [false, true]) {
    testWidgets('"+" is a primary circle with an onPrimary glyph dark=$dark', (
      tester,
    ) async {
      bookRepository.seedBooks([_book]);
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      await tester.pumpWidget(buildSubject(theme: theme));
      await tester.pumpAndSettle();
      final colors = theme.colorScheme;
      final material = tester.widget<Material>(
        find.descendant(of: _addButton, matching: find.byType(Material)),
      );
      expect(material.color, colors.primary);
      expect(material.color!.a, 1);
      expect(material.shape, const CircleBorder());
      // The capsule carries the shadow; "+" lies flat inside it.
      expect(material.elevation, 0);
      final glyph = find.descendant(
        of: _addButton,
        matching: find.byIcon(AppIcons.add),
      );
      expect(tester.widget<Icon>(glyph).size, AppIconSize.md);
      expect(IconTheme.of(tester.element(glyph)).color, colors.onPrimary);
      expect(
        _contrast(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(3),
      );
    });
  }

  group('Collections switcher', () {
    final dune = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    LibraryCollection duneNamed(String name) => LibraryCollection(
      id: dune.id,
      name: name,
      sourceCount: dune.sourceCount,
      createdAt: dune.createdAt,
      updatedAt: dune.updatedAt,
    );

    void seedDune() {
      bookRepository.seedBooks([_book, _secondBook]);
      collectionRepository.seedCollections([dune]);
      collectionRepository.seedCollectionSourceIds({
        dune.id: {_book.id},
      });
    }

    Future<void> chooseDune(WidgetTester tester) async {
      await _openCollections(tester);
      await tester.tap(
        find.byKey(
          ValueKey('collectionScopeRow-manual-${dune.id}'),
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names the whole Library and reads like the header title', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      bookRepository.seedBooks([_book]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _collectionsButton, matching: find.text('Library')),
        findsOneWidget,
      );
      for (final icon in [AppIcons.library, AppIcons.chevronDown]) {
        expect(
          find.descendant(of: _collectionsButton, matching: find.byIcon(icon)),
          findsOneWidget,
        );
      }
      expect(
        tester.getSemantics(_collectionsButton),
        isSemantics(
          label: 'Choose collection',
          value: 'Library',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('opens the Collections picker and switches scope', (
      tester,
    ) async {
      seedDune();
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await _openCollections(tester);
      expect(
        find.byKey(const ValueKey('collectionScopeRow-library')),
        findsOneWidget,
      );
      await tester.tap(find.text('Dune'));
      await tester.pumpAndSettle();
      expect(find.text(_secondBook.title), findsNothing);
      expect(
        find.descendant(of: _collectionsButton, matching: find.text('Dune')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _collectionsButton,
          matching: find.byIcon(AppIcons.collection),
        ),
        findsOneWidget,
      );

      await _openCollections(tester);
      await tester.tap(
        find.byKey(const ValueKey('collectionScopeRow-library')),
      );
      await tester.pumpAndSettle();
      expect(find.text(_secondBook.title), findsWidgets);
      expect(
        find.descendant(of: _collectionsButton, matching: find.text('Library')),
        findsOneWidget,
      );
      expect(bookRepository.getBooksCallCount, 1);
    });

    for (final dark in [false, true]) {
      testWidgets('stays legible over any cover, tinted inside a collection '
          'dark=$dark', (tester) async {
        seedDune();
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        await tester.pumpWidget(buildSubject(theme: theme));
        await tester.pumpAndSettle();
        final colors = theme.colorScheme;

        Color? segmentFill() => tester
            .widget<Material>(
              find.descendant(
                of: _collectionsButton,
                matching: find.byType(Material),
              ),
            )
            .color;
        // The capsule is translucent: check text contrast over both a black
        // and a white cover under it.
        void expectReadable(String label, Color segment) {
          for (final under in [
            const Color(0xFF000000),
            const Color(0xFFFFFFFF),
          ]) {
            final fill = Color.alphaBlend(
              segment,
              Color.alphaBlend(
                colors.surface.withValues(alpha: kAppFloatingCapsuleOpacity),
                under,
              ),
            );
            expect(
              _contrast(_labelColor(tester, label)!, fill),
              greaterThanOrEqualTo(4.5),
              reason: 'over $under',
            );
          }
        }

        expect(_labelColor(tester, 'Library'), colors.onSurface);
        expect(segmentFill()?.a ?? 0, 0);
        expectReadable('Library', const Color(0x00000000));

        await chooseDune(tester);
        expect(segmentFill(), colors.selectedControlBackground);
        expect(_labelColor(tester, 'Dune'), colors.selectedControlForeground);
        expectReadable('Dune', colors.selectedControlBackground);
      });
    }

    testWidgets('a long name truncates; the capsule keeps its cap and the '
        'start gutter', (tester) async {
      const name = 'Books for a very long weekend in the mountains far away';
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bookRepository.seedBooks([_book]);
      collectionRepository.seedCollections([duneNamed(name)]);
      collectionRepository.seedCollectionSourceIds({
        dune.id: {_book.id},
      });
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await chooseDune(tester);

      final label = find.descendant(
        of: _collectionsButton,
        matching: find.text(name),
      );
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isTrue,
      );
      final capsule = tester.getRect(_capsule);
      expect(capsule.width, closeTo(kLibraryFloatingActionsMaxWidth, .01));
      expect(
        tester.getSize(_addButton),
        const Size.square(AppSizes.buttonHeight),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a 320dp phone at 200% text the capsule stops at the start '
        'gutter', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      bookRepository.seedBooks([_book]);
      collectionRepository.seedCollections([
        duneNamed('Weekend reading list'),
      ]);
      collectionRepository.seedCollectionSourceIds({
        dune.id: {_book.id},
      });
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await chooseDune(tester);

      final capsule = tester.getRect(_capsule);
      expect(capsule.left, greaterThanOrEqualTo(AppSpacing.lg - .01));
      expect(capsule.right, closeTo(320 - AppSpacing.lg, .01));
      expect(capsule.height, closeTo(kLibraryFloatingActionsHeight, .01));
      expect(
        tester.getSize(_addButton),
        const Size.square(AppSizes.buttonHeight),
      );
      expect(tester.takeException(), isNull);
    });

    for (final (platform, expected) in [(1.5, 1.5), (3.0, 2.0)]) {
      testWidgets('label text scales to 200% and no further: $platform', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = platform;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        bookRepository.seedBooks([_book]);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final label = find.descendant(
          of: _collectionsButton,
          matching: find.text('Library'),
        );
        expect(
          MediaQuery.textScalerOf(tester.element(label)).scale(10),
          closeTo(10 * expected, .01),
        );
        expect(
          tester.getSize(_capsule).height,
          closeTo(kLibraryFloatingActionsHeight, .01),
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final reduceMotion in [false, true]) {
      testWidgets('a new name resizes the capsule over the short motion, at '
          'once with reduced motion=$reduceMotion', (tester) async {
        if (reduceMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        seedDune();
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final resize = find.descendant(
          of: _capsule,
          matching: find.byType(AnimatedSize),
        );
        if (reduceMotion) {
          expect(resize, findsNothing);
        } else {
          expect(tester.widget<AnimatedSize>(resize).duration, AppMotion.short);
        }

        // Switching scope settles without layout errors either way.
        await _openCollections(tester);
        await tester.tap(find.text('Dune'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: _collectionsButton, matching: find.text('Dune')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('switching scope rebuilds the capsule, not the Scaffold', (
      tester,
    ) async {
      seedDune();
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      await chooseDune(tester);
      expect(
        find.descendant(of: _collectionsButton, matching: find.text('Dune')),
        findsOneWidget,
      );
      expect(
        identical(tester.widget<Scaffold>(find.byType(Scaffold)), scaffold),
        isTrue,
      );
    });

    testWidgets('stays inside an empty collection so it can be left', (
      tester,
    ) async {
      bookRepository.seedBooks([_book]);
      collectionRepository.seedCollections([
        LibraryCollection(
          id: 'empty',
          name: 'Empty shelf',
          sourceCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      await tester.tap(find.text('Empty shelf'));
      await tester.pumpAndSettle();

      expect(find.text(_book.title), findsNothing);
      expect(_collectionsButton, findsOneWidget);
    });

    testWidgets('hides with "+" in selection mode and returns after it', (
      tester,
    ) async {
      bookRepository.seedBooks([_book]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.longPress(find.text(_book.title));
      await tester.pumpAndSettle();
      expect(_capsule, findsNothing);

      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
      expect(_collectionsButton, findsOneWidget);
      expect(_addButton, findsOneWidget);
    });
  });

  testWidgets('an empty library has no "+": its body offers both imports', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    expect(_addButton, findsNothing);
    // Nothing to narrow either: Collections hides with "+".
    expect(_collectionsButton, findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).floatingActionButton,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('libraryEmptyUploadFile')),
      findsOneWidget,
    );
  });

  testWidgets('"+" waits for the library to load', (tester) async {
    final gate = Completer<void>();
    bookRepository
      ..seedBooks([_book])
      ..getBooksGate = gate;
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    expect(_addButton, findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(_addButton, findsOneWidget);
  });

  testWidgets('"+" guards against double-tap while import is in-flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    var invocations = 0;
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed:
              ({required onImported, entry = LibraryImportEntry.menu}) async {
                invocations++;
                await gate.future;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_addButton);
    await tester.pump();
    await tester.tap(_addButton);
    await tester.pump();

    expect(
      invocations,
      1,
      reason: 'second tap during in-flight import must be ignored',
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  // The behavioural guard alone would leave the actions looking enabled;
  // `_addInFlight` goes through setState as a nullable onPressed instead.
  Widget gatedSubject(Completer<void> gate) => MaterialApp(
    theme: AppTheme.light(),
    home: LibraryScreen(
      bookRepository: bookRepository,
      collectionRepository: collectionRepository,
      preferencesService: preferencesService,
      onSourcePressed: (_, {onSourceOpened}) async {},
      onAddPressed:
          ({required onImported, entry = LibraryImportEntry.menu}) async {
            await gate.future;
          },
    ),
  );

  testWidgets('"+" renders disabled while import is in-flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    bookRepository.seedBooks([_book]);
    await tester.pumpWidget(gatedSubject(gate));
    await tester.pumpAndSettle();

    VoidCallback? addPressed() =>
        tester.widget<IconButton>(_addButton).onPressed;
    Color? addFill() => tester
        .widget<Material>(
          find.descendant(of: _addButton, matching: find.byType(Material)),
        )
        .color;
    final colors = AppTheme.light().colorScheme;

    expect(addPressed(), isNotNull);
    await tester.tap(_addButton);
    await tester.pump();
    expect(addPressed(), isNull);
    expect(addFill(), colors.onSurface.withValues(alpha: .12));
    // Switching collections stays available meanwhile.
    expect(
      tester.widget<TextButton>(_collectionsButton).onPressed,
      isNotNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(addPressed(), isNotNull);
  });

  testWidgets('empty-library imports render disabled while import is '
      'in-flight', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(gatedSubject(gate));
    await tester.pumpAndSettle();

    VoidCallback? uploadPressed() => tester
        .widget<ButtonStyleButton>(
          find.byKey(const ValueKey('libraryEmptyUploadFile')),
        )
        .onPressed;
    VoidCallback? articlePressed() => tester
        .widget<ButtonStyleButton>(
          find.byKey(const ValueKey('libraryEmptySaveArticle')),
        )
        .onPressed;

    expect(uploadPressed(), isNotNull);
    expect(articlePressed(), isNotNull);

    await tester.tap(find.byKey(const ValueKey('libraryEmptyUploadFile')));
    await tester.pump();
    expect(uploadPressed(), isNull);
    expect(articlePressed(), isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(uploadPressed(), isNotNull);
    expect(articlePressed(), isNotNull);
  });

  testWidgets('refreshes and resorts after reader route return delay', (
    tester,
  ) async {
    final newest = Book(
      id: 'b-newest',
      title: 'Newest',
      author: 'Author',
      filePath: '/books/newest.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 4),
    );
    final second = Book(
      id: 'b-second',
      title: 'Second',
      author: 'Author',
      filePath: '/books/second.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 3),
    );
    final target = Book(
      id: 'b-target',
      title: 'Target',
      author: 'Author',
      filePath: '/books/target.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1),
    );

    bookRepository.seedBooks([newest, second, target]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (source, {onSourceOpened}) async {
            expect(source.id, target.id);
            bookRepository.seedBooks([
              target.copyWith(lastOpenedAt: DateTime(2026, 1, 5)),
              newest,
              second,
            ]);
          },
          onAddPressed:
              ({required onImported, entry = LibraryImportEntry.menu}) async {},
        ),
      ),
    );
    await tester.pump();

    final targetFinder = find.text('Target');
    final targetTileFinder = find.byKey(
      const ValueKey('library-grid-b-target'),
    );
    final newestTileFinder = find.byKey(
      const ValueKey('library-grid-b-newest'),
    );
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetTileFinder).dx,
      greaterThan(tester.getTopLeft(newestTileFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(
      bookRepository.getBooksCallCount,
      1,
      reason: 'refreshing immediately would move the reverse Hero endpoint',
    );
    expect(
      tester.getTopLeft(targetTileFinder).dx,
      greaterThan(tester.getTopLeft(newestTileFinder).dx),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(bookRepository.getBooksCallCount, 1);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetTileFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetTileFinder).dy,
      tester.getTopLeft(newestTileFinder).dy,
    );
  });

  testWidgets('refreshes before reader route returns when source opens', (
    tester,
  ) async {
    final newest = Book(
      id: 'b-newest',
      title: 'Newest',
      author: 'Author',
      filePath: '/books/newest.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 4),
    );
    final target = Book(
      id: 'b-target',
      title: 'Target',
      author: 'Author',
      filePath: '/books/target.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1),
    );
    final routeCompleter = Completer<void>();
    VoidCallback? notifySourceOpened;

    bookRepository.seedBooks([newest, target]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (source, {onSourceOpened}) async {
            expect(source.id, target.id);
            notifySourceOpened = onSourceOpened;
            await routeCompleter.future;
          },
          onAddPressed:
              ({required onImported, entry = LibraryImportEntry.menu}) async {},
        ),
      ),
    );
    await tester.pump();

    final targetFinder = find.text('Target');
    final targetTileFinder = find.byKey(
      const ValueKey('library-grid-b-target'),
    );
    final newestTileFinder = find.byKey(
      const ValueKey('library-grid-b-newest'),
    );
    expect(bookRepository.getBooksCallCount, 1);
    expect(
      tester.getTopLeft(targetTileFinder).dx,
      greaterThan(tester.getTopLeft(newestTileFinder).dx),
    );

    await tester.tap(targetFinder);
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 1);
    expect(notifySourceOpened, isNotNull);

    bookRepository.seedBooks([
      target.copyWith(lastOpenedAt: DateTime(2026, 1, 5)),
      newest,
    ]);
    notifySourceOpened!();
    await tester.pump();
    await tester.pump();

    expect(bookRepository.getBooksCallCount, 2);
    expect(tester.getTopLeft(targetTileFinder).dx, lessThan(100));
    expect(
      tester.getTopLeft(targetTileFinder).dy,
      tester.getTopLeft(newestTileFinder).dy,
    );

    bookRepository.seedBooks([
      target.copyWith(
        lastOpenedAt: DateTime(2026, 1, 5),
        readingProgress: 0.5,
      ),
      newest,
    ]);
    routeCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      bookRepository.getBooksCallCount,
      2,
      reason: 'return refresh waits for the reverse Hero endpoint',
    );
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(
      bookRepository.getBooksCallCount,
      3,
      reason: 'return refresh picks up reader progress persisted after open',
    );
  });

  testWidgets('selection mode shows collection and delete actions in a bar', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();

    expect(_capsule, findsNothing);
    expect(find.text('Add to collection'), findsOneWidget);
    expect(find.byIcon(AppIcons.collectionAdd), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsOneWidget);
    expect(find.byIcon(AppIcons.add), findsNothing);
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(
      tester.getCenter(find.text('Add to collection')).dx,
      lessThan(tester.getCenter(find.byIcon(AppIcons.delete)).dx),
    );
    expect(
      tester.getCenter(find.byIcon(AppIcons.delete)).dx,
      greaterThan(screenWidth * 0.65),
    );
  });

  testWidgets('localized selection action stays bounded on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await preferencesService.update(
      (prefs) => prefs.copyWith(locale: const Locale('fr')),
    );
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();

    final actionRect = tester.getRect(
      find.ancestor(
        of: find.text('Ajouter à une collection'),
        matching: find.byType(FilledButton),
      ),
    );
    final scaffoldWidth = tester.getSize(find.byType(Scaffold)).width;

    expect(actionRect.left, greaterThanOrEqualTo(0));
    expect(actionRect.right, lessThanOrEqualTo(scaffoldWidth - 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual collection scope filters visible sources', (
    tester,
  ) async {
    final other = Book(
      id: 'b-2',
      title: 'Domain-Driven Design',
      author: 'Eric Evans',
      filePath: '/books/ddd.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 2),
    );
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book, other]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsOneWidget);

    await _openCollections(tester);
    await tester.tap(find.text('Dune'));
    await tester.pumpAndSettle();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsNothing);
    // The title names the scope.
    expect(_headerText('Dune'), findsOneWidget);
    expect(find.text('Library'), findsNothing);

    await _openCollections(tester);
    await tester.tap(find.byKey(const ValueKey('collectionScopeRow-library')));
    await tester.pumpAndSettle();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsOneWidget);
    expect(_headerText('Library'), findsOneWidget);
    expect(bookRepository.getBooksCallCount, 1);
  });

  testWidgets(
    'collection scope sheet shows favourites without permanent section',
    (
      tester,
    ) async {
      bookRepository.seedBooks([_book]);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await _openCollections(tester);

      final favouritesRow = find.byKey(
        const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
      );

      expect(find.text('Permanent'), findsNothing);
      expect(favouritesRow, findsOneWidget);
      expect(
        find.descendant(
          of: favouritesRow,
          matching: find.byIcon(AppIcons.collectionFavourites),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: favouritesRow,
          matching: find.byIcon(AppIcons.moreVertical),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('favourites collection scope uses localized UI labels', (
    tester,
  ) async {
    await preferencesService.update(
      (prefs) => prefs.copyWith(locale: const Locale('ru')),
    );
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);

    final sheet = find.byType(ActionBottomSheetLayout);
    final searchField = find.descendant(
      of: sheet,
      matching: find.byType(TextField),
    );
    final favouritesRow = find.byKey(
      const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
    );

    expect(favouritesRow, findsOneWidget);
    final favouritesLabel = find.descendant(
      of: favouritesRow,
      matching: find.text('Избранное'),
    );
    expect(favouritesLabel, findsOneWidget);
    expect(find.text('Favourites'), findsNothing);

    await tester.enterText(searchField, 'избр');
    await tester.pumpAndSettle();

    expect(favouritesRow, findsOneWidget);
    expect(favouritesLabel, findsOneWidget);

    await tester.tap(favouritesRow);
    await tester.pumpAndSettle();

    expect(_headerText('Избранное'), findsOneWidget);
    expect(find.text('Favourites'), findsNothing);
  });

  testWidgets('collection scope sheet filters scopes by search query', (
    tester,
  ) async {
    final articleRepository = _FakeArticleRepository()
      ..seedArticles([
        Article(
          id: 'a-1',
          title: 'Article',
          url: 'https://tproger.ru/a',
          siteName: 'Tproger',
          author: 'Seiken',
          contentPath: '/articles/a-1/article.json',
          addedAt: DateTime(2026, 1, 2),
        ),
      ]);
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject(articleRepository: articleRepository));
    await tester.pump();

    await _openCollections(tester);

    final sheet = find.byType(ActionBottomSheetLayout);
    final sheetTopBeforeSearch = tester.getTopLeft(sheet).dy;
    final sheetHeightBeforeSearch = tester.getSize(sheet).height;
    final searchField = find.widgetWithText(TextField, 'Search collections...');
    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final siteRow = find.byKey(
      const ValueKey('collectionScopeRow-site-tproger'),
    );
    final authorRow = find.byKey(
      const ValueKey('collectionScopeRow-author-seiken (tproger.ru)'),
    );

    expect(searchField, findsOneWidget);
    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
    expect(find.text('Seiken (tproger.ru)'), findsOneWidget);

    await tester.enterText(searchField, 'tpro');
    await tester.pumpAndSettle();

    expect(manualRow, findsNothing);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);

    await tester.enterText(searchField, 'missing');
    await tester.pumpAndSettle();

    expect(find.text('No matching collections'), findsOneWidget);
    expect(siteRow, findsNothing);
    expect(tester.getTopLeft(sheet).dy, closeTo(sheetTopBeforeSearch, 0.1));
    expect(tester.getSize(sheet).height, closeTo(sheetHeightBeforeSearch, 0.1));

    await tester.tap(
      find.descendant(
        of: find.byType(ActionBottomSheetLayout),
        matching: find.byTooltip('Clear search'),
      ),
    );
    await tester.pumpAndSettle();

    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
  });

  testWidgets('collection scope sheet uses scroll edge fades', (tester) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);

    final sheet = find.byType(ActionBottomSheetLayout);
    final fadeStack = find.descendant(
      of: sheet,
      matching: find.byType(ScrollEdgeFadeStack),
    );

    final sheetWidget = tester.widget<ActionBottomSheetLayout>(sheet);

    expect(find.byType(AppBottomSafeArea), findsOneWidget);
    expect(sheetWidget.bodyPadding, EdgeInsets.zero);
    expect(fadeStack, findsOneWidget);
    expect(
      tester.getSize(fadeStack).width,
      closeTo(tester.getSize(sheet).width, 0.1),
    );
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ScrollEdgeFade)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
      findsOneWidget,
    );
    final listView = tester.widget<ListView>(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
    );
    expect(
      listView.padding,
      const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.sm,
        0,
        AppSpacing.xl - AppSizes.iconActionOutset,
        AppSpacing.lg,
      ),
    );
  });

  testWidgets('collection scope rows retain native pressed feedback', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);

    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final rowInkWell = tester.widget<InkWell>(
      find.ancestor(of: manualRow, matching: find.byType(InkWell)),
    );

    expect(
      rowInkWell.overlayColor?.resolve({WidgetState.pressed}),
      isNot(Colors.transparent),
    );
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final scale in [1.0, 2.0]) {
      for (final target in [
        'manual-collection-1',
        'favourites-readflex:favourites',
      ]) {
        testWidgets(
          'Collections menu aligns with Close: $locale/$scale/$target',
          (
            tester,
          ) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await preferencesService.update((p) => p.copyWith(locale: locale));
            bookRepository.seedBooks([_book]);
            collectionRepository.seedCollections([
              LibraryCollection(
                id: 'collection-1',
                name: 'Reading',
                sourceCount: 1,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ]);
            collectionRepository.seedCollectionSourceIds({
              'collection-1': {_book.id},
            });
            await tester.pumpWidget(buildSubject());
            await tester.pumpAndSettle();
            await _openCollections(tester);

            final action = find.byKey(
              ValueKey('collectionScopeManage-$target'),
            );
            final bounds = tester.getRect(action);
            final strings = ReadflexLocalizations.of(tester.element(action))!;
            final close = tester.getRect(find.byTooltip(strings.commonClose));
            expect(bounds.size, const Size.square(48));
            expect(bounds.center.dx, closeTo(close.center.dx, .01));
            final sheet = tester.getRect(find.byType(BottomSheet));
            expect(bounds.left, greaterThanOrEqualTo(sheet.left));
            expect(bounds.right, lessThanOrEqualTo(sheet.right));
            final icon = tester.getRect(
              find.descendant(
                of: action,
                matching: find.byIcon(AppIcons.moreVertical),
              ),
            );
            final search = tester.getRect(
              find.descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(SearchField),
              ),
            );
            final rtl = locale.languageCode == 'ar';
            expect(
              rtl ? icon.left : icon.right,
              rtl ? search.left : search.right,
            );
            await tester.tapAt(
              Offset(
                rtl ? bounds.left + 1 : bounds.right - 1,
                bounds.center.dy,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('manageCollectionContent')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'Manage returns to the filtered Collections list in the same sheet',
    (tester) async {
      bookRepository.seedBooks([_book]);
      collectionRepository.seedCollections([
        LibraryCollection(
          id: 'collection-1',
          name: 'Dune',
          sourceCount: 1,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      collectionRepository.seedCollectionSourceIds({
        'collection-1': {_book.id},
      });
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      final sheet = tester.element(find.byType(BottomSheet));
      await tester.enterText(find.byType(TextField).last, 'Dune');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
      );
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(BottomSheet)), same(sheet));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Dune',
      );
      expect(
        find.byKey(const ValueKey('collectionScopeRow-manual-collection-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Manage preserves Collections scroll offset on system Back', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);
    final collections = List.generate(
      30,
      (index) => LibraryCollection(
        id: 'collection-$index',
        name: 'Reading ${index.toString().padLeft(2, '0')}',
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    collectionRepository.seedCollections(collections);
    collectionRepository.seedCollectionSourceIds({
      for (final collection in collections) collection.id: {_book.id},
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    final reads = bookRepository.getBooksCallCount;
    await _openCollections(tester);
    final action = find.byKey(
      const ValueKey('collectionScopeManage-manual-collection-10'),
    );
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    final scrollable = Scrollable.of(tester.element(action));
    final offset = scrollable.position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(Scrollable.of(tester.element(action)), same(scrollable));
    expect(scrollable.position.pixels, offset);
    expect(action.hitTestable(), findsOneWidget);
    expect(bookRepository.getBooksCallCount, reads);
  });

  testWidgets('collection scope rows keep equal height across sections', (
    tester,
  ) async {
    final articleRepository = _FakeArticleRepository()
      ..seedArticles([
        Article(
          id: 'a-1',
          title: 'Article',
          url: 'https://tproger.ru/a',
          siteName: 'Tproger',
          author: 'Seiken',
          contentPath: '/articles/a-1/article.json',
          addedAt: DateTime(2026, 1, 2),
        ),
      ]);
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject(articleRepository: articleRepository));
    await tester.pump();

    await _openCollections(tester);

    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final siteRow = find.byKey(
      const ValueKey('collectionScopeRow-site-tproger'),
    );
    final authorRow = find.byKey(
      const ValueKey('collectionScopeRow-author-seiken (tproger.ru)'),
    );

    expect(manualRow, findsOneWidget);
    expect(siteRow, findsOneWidget);
    expect(authorRow, findsOneWidget);
    expect(tester.getSize(manualRow).height, tester.getSize(siteRow).height);
    expect(tester.getSize(manualRow).height, tester.getSize(authorRow).height);

    // Books and Articles rows make the list scroll; at its end the last row
    // still keeps breathing room above the sheet edge.
    final sheet = find.byType(ActionBottomSheetLayout);
    await tester.drag(
      find.descendant(of: sheet, matching: find.byType(ListView)),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    final visibleGapBelowAuthor =
        tester.getBottomLeft(sheet).dy - tester.getBottomLeft(authorRow).dy;
    expect(visibleGapBelowAuthor, greaterThanOrEqualTo(AppSpacing.lg));
  });

  for (final closeMethod in ['close', 'back']) {
    testWidgets('collection $closeMethod guards staged edits without saving', (
      tester,
    ) async {
      final collection = LibraryCollection(
        id: 'collection-1',
        name: 'Reading',
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      bookRepository.seedBooks([_book]);
      collectionRepository.seedCollections([collection]);
      collectionRepository.seedCollectionSourceIds({
        collection.id: {_book.id},
      });
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      await tester.tap(
        find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
      );
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('manageCollectionContent'));
      await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        'Changed',
      );
      await tester.tap(
        find.byKey(const ValueKey('collectionSourceRemove-b-1')),
      );
      await tester.pumpAndSettle();
      // No Cancel sits beside Save: leaving is the header's job.
      expect(find.text('Cancel'), findsNothing);
      Future<void> close() async {
        switch (closeMethod) {
          case 'close':
            await tester.tap(find.byTooltip('Close'));
          case 'back':
            await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
      }

      await close();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('discardCollectionContent')),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
      await close();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(
        find.byType(BottomSheet),
        closeMethod == 'close' ? findsNothing : findsOneWidget,
        reason: 'Close exits the flow; Back returns to Collections',
      );
      expect(
        (await collectionRepository.getCollections()).single.name,
        'Reading',
      );
      expect(collectionRepository.addedSourceIdsByCollection[collection.id], {
        _book.id,
      });
      expect(bookRepository.getBooksCallCount, 1);
    });
  }

  testWidgets('manual collection management removes a source', (
    tester,
  ) async {
    final other = Book(
      id: 'b-2',
      title: 'Domain-Driven Design',
      author: 'Eric Evans',
      filePath: '/books/ddd.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026, 1, 2),
    );
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book, other]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id, other.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage collection'), findsOneWidget);

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    final saveFinder = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    var saveButton = tester.widget<FilledButton>(saveFinder);
    final sheetHeightBeforeRemoval = tester.getSize(sheet).height;
    final saveTopBeforeRemoval = tester.getTopLeft(saveFinder).dy;
    expect(saveButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('collectionSourceRemove-b-1')),
    );
    await tester.pump();

    expect(
      find.descendant(of: sheet, matching: find.text('Flutter in Action')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(tester.getSize(sheet).height, sheetHeightBeforeRemoval);
    expect(
      tester.getTopLeft(saveFinder).dy,
      closeTo(saveTopBeforeRemoval, 0.1),
    );

    expect(
      find.descendant(of: sheet, matching: find.text('Flutter in Action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('collectionSourceUndo-b-1')),
      findsOneWidget,
    );
    expect(collectionRepository.addedSourceIdsByCollection[collection.id], {
      _book.id,
      other.id,
    });

    saveButton = tester.widget<FilledButton>(saveFinder);
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(collectionRepository.addedSourceIdsByCollection[collection.id], {
      other.id,
    });
    expect(find.text('Manage collection'), findsNothing);
  });

  testWidgets('manage collection shows book and article counts', (
    tester,
  ) async {
    final articleRepository = _FakeArticleRepository()
      ..seedArticles([
        Article(
          id: 'article-1',
          title: 'Saved article',
          url: 'https://example.com/a',
          siteName: 'Example',
          author: 'Author',
          contentPath: '/articles/article-1/article.json',
          addedAt: DateTime(2026, 1, 2),
        ),
      ]);
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Mixed collection',
      sourceCount: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id, 'article-1'},
    });

    await tester.pumpWidget(
      buildSubject(articleRepository: articleRepository),
    );
    await tester.pump();

    await _openCollections(tester);
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    expect(
      find.descendant(of: sheet, matching: find.text('1 book, 1 article')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('collectionSourceRemove-b-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sheet, matching: find.text('1 article')),
      findsOneWidget,
    );
  });

  testWidgets('manage collection empty state is centered in list area', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Empty collection',
      sourceCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({collection.id: <String>{}});

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    final countLabel = find.descendant(
      of: sheet,
      matching: find.text('0 books/articles'),
    );
    final emptyLabel = find.descendant(
      of: sheet,
      matching: find.text('No items in this collection'),
    );
    expect(countLabel, findsOneWidget);
    expect(emptyLabel, findsOneWidget);

    // Delete shares the count row, so that row's 48dp target ends the header
    // area; the empty placeholder pads itself and the footer's 8dp top follows.
    final deleteAction = find.descendant(
      of: sheet,
      matching: find.widgetWithText(TextButton, 'Delete collection'),
    );
    expect(
      tester.getCenter(countLabel).dy,
      closeTo(tester.getCenter(deleteAction).dy, .5),
    );
    final listAreaTop = tester.getBottomLeft(deleteAction).dy + AppSpacing.md;
    final save = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    final listAreaBottom = tester.getTopLeft(save).dy - AppSpacing.sm;
    final expectedCenter = (listAreaTop + listAreaBottom) / 2;

    expect(tester.getCenter(emptyLabel).dy, closeTo(expectedCenter, 1));
  });

  for (final sourceType in SourceType.values) {
    for (final keyboard in [0.0, 320.0]) {
      testWidgets(
        'one $sourceType in collection needs no scrolling with inset $keyboard',
        (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final collection = LibraryCollection(
            id: 'collection-1',
            name: 'Small collection',
            sourceCount: 1,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );
          final articleRepository = _FakeArticleRepository();
          final isBook = sourceType == SourceType.book;
          if (isBook) {
            bookRepository.seedBooks([_book]);
          } else {
            articleRepository.seedArticles([
              Article(
                id: 'article-1',
                title: 'Saved article',
                url: 'https://example.com/article',
                contentPath: '/articles/article-1/article.json',
                addedAt: DateTime(2026),
              ),
            ]);
          }
          final sourceId = isBook ? _book.id : 'article-1';
          collectionRepository.seedCollections([collection]);
          collectionRepository.seedCollectionSourceIds({
            collection.id: {sourceId},
          });
          await tester.pumpWidget(
            buildSubject(articleRepository: articleRepository),
          );
          await tester.pump();
          await _openCollections(tester);
          await tester.tap(
            find.byKey(
              const ValueKey('collectionScopeManage-manual-collection-1'),
            ),
          );
          await tester.pumpAndSettle();
          final sheet = find.byKey(const ValueKey('manageCollectionContent'));
          final viewport = find.descendant(
            of: sheet,
            matching: find.byType(ListView),
          );
          expect(viewport, findsOneWidget);
          final scroll = tester.state<ScrollableState>(
            find.descendant(
              of: viewport,
              matching: find.byType(Scrollable),
            ),
          );
          expect(scroll.position.maxScrollExtent, 0);
          final fades = tester.widgetList<ScrollEdgeFade>(
            find.descendant(of: sheet, matching: find.byType(ScrollEdgeFade)),
          );
          expect(fades.every((fade) => !fade.visible), isTrue);
          expect(
            find
                .byKey(ValueKey('collectionSourceRemove-$sourceId'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('manage collection item list uses scroll edge fades', (
    tester,
  ) async {
    final books = List.generate(
      12,
      (index) => Book(
        id: 'book-$index',
        title: 'Book $index',
        author: 'Author',
        filePath: '/books/book-$index.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 1, index + 1),
      ),
    );
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Large collection',
      sourceCount: books.length,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks(books);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: books.map((book) => book.id).toSet(),
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('manageCollectionContent'));
    final fadeStack = find.descendant(
      of: sheet,
      matching: find.byType(ScrollEdgeFadeStack),
    );

    expect(fadeStack, findsOneWidget);
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
      findsOneWidget,
    );
    final listView = tester.widget<ListView>(
      find.descendant(of: fadeStack, matching: find.byType(ListView)),
    );
    expect(
      listView.padding,
      const EdgeInsets.only(bottom: AppSpacing.lg),
    );
    expect(
      find.descendant(of: fadeStack, matching: find.byType(ScrollEdgeFade)),
      findsNWidgets(2),
    );
    expect(
      tester.getSize(fadeStack).width,
      closeTo(tester.getSize(sheet).width, 0.1),
    );
    expect(
      tester.getSize(fadeStack).height,
      lessThanOrEqualTo(_collectionSourcesMaxHeightForTest),
    );
    final scrollable = find.descendant(
      of: fadeStack,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    List<bool> visibleEdges() => tester
        .widgetList<ScrollEdgeFade>(
          find.descendant(of: fadeStack, matching: find.byType(ScrollEdgeFade)),
        )
        .map((fade) => fade.visible)
        .toList();
    expect(visibleEdges(), [false, true]);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(visibleEdges(), [true, false]);
  });

  testWidgets(
    'favourites management removes a source without delete controls',
    (
      tester,
    ) async {
      final other = Book(
        id: 'b-2',
        title: 'Domain-Driven Design',
        author: 'Eric Evans',
        filePath: '/books/ddd.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 1, 2),
      );
      bookRepository.seedBooks([_book, other]);
      await collectionRepository.addSourcesToFavourites(
        sourceIds: [_book.id, other.id],
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await _openCollections(tester);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'collectionScopeManage-favourites-readflex:favourites',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('manageCollectionContent'));
      expect(find.text('Manage collection'), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(find.text('Delete collection'), findsNothing);

      final saveFinder = find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, 'Save'),
      );
      var saveButton = tester.widget<FilledButton>(saveFinder);
      expect(saveButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('collectionSourceRemove-b-1')),
      );
      await tester.pumpAndSettle();

      saveButton = tester.widget<FilledButton>(saveFinder);
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(collectionRepository.favouriteSourceIds, {other.id});
      expect(find.text('Manage collection'), findsNothing);
    },
  );

  testWidgets('manual collection management deletes collection', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    final manageStepHeight = tester
        .getSize(
          find.byKey(const ValueKey('manageCollectionContent')),
        )
        .height;
    final stepFrame = find.byKey(const ValueKey('manageCollectionStepFrame'));
    expect(stepFrame, findsOneWidget);
    expect(tester.getSize(stepFrame).height, manageStepHeight);

    await tester.tap(find.text('Delete collection'));
    await tester.pump();

    expect(find.byType(FractionalTranslation), findsWidgets);
    expect(tester.getSize(stepFrame).height, manageStepHeight);

    await tester.pumpAndSettle();

    final deleteStep = find.byKey(const ValueKey('deleteCollectionContent'));
    expect(deleteStep, findsOneWidget);
    expect(tester.getSize(deleteStep).height, lessThan(manageStepHeight));
    expect(find.text('Manage collection'), findsNothing);
    expect(find.text('Delete collection?'), findsOneWidget);

    final deleteHeader = find.descendant(
      of: deleteStep,
      matching: find.byType(BottomSheetHeader),
    );
    final deleteMessage = find.descendant(
      of: deleteStep,
      matching: find.text(
        'This removes "Dune" only. Books and articles stay in your library.',
      ),
    );
    final deleteButton = find.descendant(
      of: deleteStep,
      matching: find.widgetWithText(OutlinedButton, 'Delete'),
    );
    // Start-aligned under the header like the sibling confirmations.
    expect(deleteMessage, findsOneWidget);
    final messageRect = tester.getRect(deleteMessage);
    final stepRect = tester.getRect(deleteStep);
    expect(
      messageRect.top,
      closeTo(tester.getBottomLeft(deleteHeader).dy + AppSpacing.sm, 1),
    );
    expect(messageRect.left, closeTo(stepRect.left + AppSpacing.xl, 1));
    expect(
      tester.widget<Text>(deleteMessage).textAlign,
      isNot(TextAlign.center),
    );
    expect(
      tester.getTopLeft(deleteButton).dy - messageRect.bottom,
      greaterThanOrEqualTo(AppSpacing.xl),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await collectionRepository.getCollections(), isEmpty);
    expect(await collectionRepository.getCollectionSourceIds(), isEmpty);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('manual collection management renames from footer action', (
    tester,
  ) async {
    final collection = LibraryCollection(
      id: 'collection-1',
      name: 'Dune',
      sourceCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    bookRepository.seedBooks([_book]);
    collectionRepository.seedCollections([collection]);
    collectionRepository.seedCollectionSourceIds({
      collection.id: {_book.id},
    });

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await _openCollections(tester);
    await tester.tap(
      find.byKey(const ValueKey('collectionScopeManage-manual-collection-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collection name'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    final nameField = find.descendant(
      of: find.byKey(const ValueKey('manageCollectionContent')),
      matching: find.byType(TextField),
    );
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, 'Dune Saga');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final collections = await collectionRepository.getCollections();
    expect(collections.single.name, 'Dune Saga');
    expect(find.text('Manage collection'), findsNothing);
  });

  testWidgets('adds selected source to favourites from add collection sheet', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.collectionAdd));
    await tester.pumpAndSettle();

    final favouritesRow = find.widgetWithText(InkWell, 'Favourites');

    expect(favouritesRow, findsOneWidget);
    expect(find.byIcon(AppIcons.collectionFavourites), findsOneWidget);

    await tester.tap(favouritesRow);
    await tester.pumpAndSettle();

    expect(collectionRepository.favouriteSourceIds, {_book.id});
    expect(find.text('Add to collection'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('creates collection from selected source', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.longPress(find.text('Flutter in Action'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.collectionAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, 'New collection name');
    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Create and add'), findsOneWidget);
    expect(
      tester.getCenter(nameField).dy,
      lessThan(tester.getCenter(find.text('Create and add')).dy),
    );

    await tester.enterText(
      nameField,
      'Dune',
    );
    await tester.pump();
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();

    expect(collectionRepository.addedSourceIdsByCollection, isNotEmpty);
    expect(
      collectionRepository.addedSourceIdsByCollection.values.single,
      contains(_book.id),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  // Swipe-delete waits for the real write: the row only leaves the tree
  // once storage confirms, and a failure springs it back with a toast.
  Future<void> pumpListLayout(WidgetTester tester) async {
    await preferencesService.update(
      (prefs) => prefs.copyWith(libraryLayoutMode: LibraryLayoutMode.list.id),
    );
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    expect(find.byType(LibraryListView), findsOneWidget);
  }

  Finder listRow(Book book) => find.descendant(
    of: find.byType(LibraryListView),
    matching: find.text(book.title),
  );

  // The toast overlay has a Dismissible of its own; count only list rows.
  Finder listRows() => find.descendant(
    of: find.byType(LibraryListView),
    matching: find.byType(Dismissible),
  );

  Future<void> swipeRow(WidgetTester tester, Book book) async {
    final gesture = await tester.startGesture(tester.getCenter(listRow(book)));
    // The first move only resolves the gesture arena; the second moves it
    // past the dismiss threshold.
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-470, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Delete this item?'), findsOneWidget);
  }

  Future<void> swipeAndConfirmDelete(WidgetTester tester, Book book) async {
    await swipeRow(tester, book);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  // The toast overlay inserts after a frame of its own.
  Future<void> pumpUntilToast(WidgetTester tester, Finder toast) async {
    for (var frame = 0; frame < 10 && toast.evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(toast, findsOneWidget);
  }

  testWidgets('swipe delete removes the row only after the write completes', (
    tester,
  ) async {
    bookRepository.seedBooks([_book, _secondBook]);
    final gate = Completer<void>();
    bookRepository.deleteGate = gate;
    await pumpListLayout(tester);

    await swipeAndConfirmDelete(tester, _book);
    await tester.pump(const Duration(milliseconds: 500));

    // Write still in flight: the row is held, not collapsed or removed.
    expect(listRows(), findsNWidgets(2));
    expect(listRow(_book), findsOneWidget);
    expect(find.textContaining('deleted'), findsNothing);
    expect(await bookRepository.getBooks(), hasLength(2));

    gate.complete();
    await tester.pumpAndSettle();

    expect(listRows(), findsOneWidget);
    expect(listRow(_book), findsNothing);
    expect(listRow(_secondBook), findsOneWidget);
    await pumpUntilToast(tester, find.textContaining('deleted'));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('swipe delete failure keeps the row and shows the toast', (
    tester,
  ) async {
    bookRepository.seedBooks([_book, _secondBook]);
    bookRepository.failOnIds = {_book.id};
    await pumpListLayout(tester);
    final restingRect = tester.getRect(listRow(_book));

    await swipeAndConfirmDelete(tester, _book);

    await pumpUntilToast(tester, find.text('Failed to delete the item'));
    expect(listRows(), findsNWidgets(2));
    // The row sprang back to its resting position.
    expect(tester.getRect(listRow(_book)), restingRect);
    expect(listRow(_book).hitTestable(), findsOneWidget);
    expect(await bookRepository.getBooks(), hasLength(2));
    expect(tester.takeException(), isNull);

    // Another swipe still works after the failed attempt.
    bookRepository.failOnIds = const {};
    await swipeAndConfirmDelete(tester, _book);
    expect(listRow(_book), findsNothing);
    expect(listRows(), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });

  testWidgets('swipe delete cancel springs the row back without a write', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);
    await pumpListLayout(tester);
    final restingRect = tester.getRect(listRow(_book));

    await swipeRow(tester, _book);
    await tester.tap(find.widgetWithText(FilledButton, 'Keep'));
    await tester.pumpAndSettle();

    expect(tester.getRect(listRow(_book)), restingRect);
    expect(await bookRepository.getBooks(), hasLength(1));
    expect(find.textContaining('deleted'), findsNothing);
  });

  group('Continue reading card', () {
    final card = find.byType(LibraryContinueReadingCard);
    final reading = Book(
      id: 'b-reading',
      title: 'Reading Now',
      author: 'Current Author',
      filePath: '/books/reading.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
      readingProgress: .4,
      lastOpenedAt: DateTime(2026, 3),
    );
    final earlier = Book(
      id: 'b-earlier',
      title: 'Read Earlier',
      filePath: '/books/earlier.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
      readingProgress: .7,
      lastOpenedAt: DateTime(2026, 2),
    );
    final finished = Book(
      id: 'b-finished',
      title: 'Finished',
      filePath: '/books/finished.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
      readingProgress: 1,
      isFinished: true,
      lastOpenedAt: DateTime(2026, 4),
    );

    Future<void> useLayout(LibraryLayoutMode mode) => preferencesService.update(
      (prefs) => prefs.copyWith(libraryLayoutMode: mode.id),
    );
    // A source's row or tile in either layout.
    Finder listed(String id) => find.byWidgetPredicate(
      (widget) =>
          (widget is BookLibraryListTile && widget.source.id == id) ||
          (widget is BookLibraryGridTile && widget.source.id == id),
    );

    for (final mode in LibraryLayoutMode.values) {
      testWidgets('shows the most recent eligible source first: ${mode.id}', (
        tester,
      ) async {
        await useLayout(mode);
        bookRepository.seedBooks([earlier, finished, reading, _book]);
        final opened = <LibrarySource>[];
        await tester.pumpWidget(buildSubject(onSourcePressed: opened.add));
        await tester.pumpAndSettle();

        expect(card, findsOneWidget);
        expect(
          tester.widget<LibraryContinueReadingCard>(card).source.id,
          reading.id,
        );
        final scrollView = switch (mode) {
          LibraryLayoutMode.list => find.byType(LibraryListView),
          LibraryLayoutMode.grid => find.byType(LibraryGridView),
        };
        expect(find.descendant(of: scrollView, matching: card), findsOneWidget);
        // The card is the book's place; the rest stay in their order.
        expect(listed(reading.id), findsNothing);
        for (final other in [earlier, finished, _book]) {
          expect(listed(other.id), findsOneWidget, reason: other.title);
        }
        final header = tester.getRect(find.byType(LibraryHeader));
        expect(
          tester.getRect(card).top,
          closeTo(header.bottom + kLibraryContentTopPadding, .01),
        );

        await tester.tap(card);
        await tester.pump();
        expect(opened.single.id, reading.id);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      });
    }

    for (final mode in LibraryLayoutMode.values) {
      testWidgets('long-press on the card selects its book in place: '
          '${mode.id}', (tester) async {
        await useLayout(mode);
        bookRepository.seedBooks([reading, _book, earlier]);
        final opened = <LibrarySource>[];
        await tester.pumpWidget(buildSubject(onSourcePressed: opened.add));
        await tester.pumpAndSettle();
        final firstListed = tester.getRect(listed(earlier.id));

        await tester.longPress(card);
        await tester.pumpAndSettle();
        expect(find.text('Selected: 1'), findsOneWidget);
        expect(opened, isEmpty);
        expect(
          tester.widget<LibraryContinueReadingCard>(card).isSelected,
          isTrue,
        );
        expect(listed(reading.id), findsNothing);
        expect(tester.getRect(listed(earlier.id)), firstListed);

        // A tap toggles it like a row, without opening the reader.
        await tester.tap(listed(_book.id));
        await tester.pumpAndSettle();
        expect(find.text('Selected: 2'), findsOneWidget);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('Selected: 1'), findsOneWidget);
        expect(
          tester.widget<LibraryContinueReadingCard>(card).isSelected,
          isFalse,
        );
        expect(opened, isEmpty);
      });
    }

    testWidgets('is absent when nothing is in progress', (tester) async {
      bookRepository.seedBooks([
        finished,
        _book,
        Book(
          id: 'b-zero',
          title: 'Opened at zero',
          filePath: '/books/zero.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          lastOpenedAt: DateTime(2026, 5),
        ),
        Book(
          id: 'b-unopened',
          title: 'Progress without open date',
          filePath: '/books/unopened.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          readingProgress: .5,
        ),
      ]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });

    testWidgets('hides while searching and returns when cleared', (
      tester,
    ) async {
      bookRepository.seedBooks([reading, _book]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Reading');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      // Without the card the book is listed again.
      expect(listed(reading.id), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    });

    testWidgets('hides inside a built-in collection', (tester) async {
      bookRepository.seedBooks([reading, _comicBook]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await _openCollections(tester);
      await tester.tap(_builtInRow(LibraryCollectionScopeType.books));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(listed(reading.id), findsOneWidget);
      await _openCollections(tester);
      await tester.tap(
        find.byKey(const ValueKey('collectionScopeRow-library')),
      );
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    });

    testWidgets('hides inside a collection', (tester) async {
      final collection = LibraryCollection(
        id: 'collection-1',
        name: 'Dune',
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      bookRepository.seedBooks([reading, _book]);
      collectionRepository.seedCollections([collection]);
      collectionRepository.seedCollectionSourceIds({
        collection.id: {reading.id},
      });
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await _openCollections(tester);
      await tester.tap(find.text('Dune'));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });

    for (final mode in LibraryLayoutMode.values) {
      testWidgets('stays while selecting, so the covers under it do not '
          'move: ${mode.id}', (tester) async {
        await useLayout(mode);
        bookRepository.seedBooks([reading, _book, earlier]);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final cardRect = tester.getRect(card);
        final bookRect = tester.getRect(listed(_book.id));

        await tester.longPress(listed(_book.id));
        await tester.pumpAndSettle();
        expect(find.text('Selected: 1'), findsOneWidget);
        expect(tester.getRect(card), cardRect);
        expect(tester.getRect(listed(_book.id)), bookRect);
        expect(listed(reading.id), findsNothing);
        expect(
          tester.widget<LibraryContinueReadingCard>(card).isSelectionMode,
          isTrue,
        );

        await tester.tap(find.byTooltip('Cancel selection'));
        await tester.pumpAndSettle();
        expect(tester.getRect(card), cardRect);
        expect(
          tester.widget<LibraryContinueReadingCard>(card).isSelectionMode,
          isFalse,
        );
      });
    }
  });

  group('empty library', () {
    testWidgets('commands open import at the file and article steps', (
      tester,
    ) async {
      final entries = <LibraryImportEntry>[];
      await tester.pumpWidget(
        buildSubject(
          onAddPressed:
              ({required onImported, entry = LibraryImportEntry.menu}) async {
                entries.add(entry);
              },
        ),
      );
      await tester.pumpAndSettle();
      expect(_capsule, findsNothing);
      expect(find.text('Books, comics and PDF'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Upload a file'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Save an article'),
        findsOneWidget,
      );
      expect(_addButton, findsNothing);
      await tester.tap(find.text('Upload a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save an article'));
      await tester.pumpAndSettle();
      expect(entries, [LibraryImportEntry.file, LibraryImportEntry.article]);
    });
  });

  group('openImportOnStart', () {
    testWidgets('opens file import once after the first frame', (
      tester,
    ) async {
      final entries = <LibraryImportEntry>[];
      late VoidCallback imported;
      Widget subject() => buildSubject(
        openImportOnStart: true,
        onAddPressed:
            ({required onImported, entry = LibraryImportEntry.menu}) async {
              entries.add(entry);
              imported = onImported;
            },
      );
      // pumpWidget renders the first frame; the post-frame callback follows.
      await tester.pumpWidget(subject());
      expect(entries, [LibraryImportEntry.file]);
      await tester.pump();
      expect(entries, [LibraryImportEntry.file]);
      await tester.pumpAndSettle();

      // Rebuilding the same screen does not reopen import.
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(entries, [LibraryImportEntry.file]);

      // It is the ordinary import flow: a commit refreshes Library.
      bookRepository.seedBooks([_book]);
      imported();
      await tester.pumpAndSettle();
      expect(find.text(_book.title), findsWidgets);
    });

    testWidgets('does nothing by default', (tester) async {
      final entries = <LibraryImportEntry>[];
      await tester.pumpWidget(
        buildSubject(
          onAddPressed:
              ({required onImported, entry = LibraryImportEntry.menu}) async {
                entries.add(entry);
              },
        ),
      );
      await tester.pumpAndSettle();
      expect(entries, isEmpty);
    });
  });

  group('content bottom inset', () {
    testWidgets('clears the bottom capsule and the home indicator; the space '
        'stays while selecting', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      await preferencesService.update(
        (prefs) => prefs.copyWith(libraryLayoutMode: LibraryLayoutMode.list.id),
      );
      bookRepository.seedBooks([_book, _secondBook]);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      double bottomPadding() => tester
          .widget<ListView>(
            find.descendant(
              of: find.byType(LibraryListView),
              matching: find.byType(ListView),
            ),
          )
          .padding!
          .resolve(TextDirection.ltr)
          .bottom;
      // 56dp capsule + 8dp lift + 16dp Scaffold margin + 16dp gap.
      const clearance =
          kLibraryFloatingActionsHeight +
          kLibraryFloatingActionsLift +
          AppSpacing.lg +
          AppSpacing.lg;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
        isNull,
      );
      // The capsule sits on the inset; the content clears both.
      expect(bottomPadding(), clearance + 34);
      final capsule = tester.getRect(_capsule);
      final lastRow = tester.getRect(
        find.ancestor(
          of: find.text(_secondBook.title),
          matching: find.byType(BookLibraryListTile),
        ),
      );
      expect(lastRow.bottom, lessThanOrEqualTo(capsule.top));

      await tester.longPress(find.text(_book.title));
      await tester.pumpAndSettle();
      expect(find.byType(LibrarySelectionBar), findsOneWidget);
      expect(_addButton, findsNothing);
      // The bar owns the inset; the button's space is kept, so the end of
      // the list does not move.
      expect(bottomPadding(), clearance);

      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
      expect(find.byType(LibrarySelectionBar), findsNothing);
      expect(_addButton, findsOneWidget);
      expect(bottomPadding(), clearance + 34);
    });
  });

  group('content top edge', () {
    final topFade = find.byWidgetPredicate(
      (widget) => widget is ScrollEdgeFade && widget.edge == ScrollFadeEdge.top,
    );

    for (final mode in LibraryLayoutMode.values) {
      testWidgets('a long list scrolls under a band below the search field, '
          'never flush against it: ${mode.id}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await preferencesService.update(
          (prefs) => prefs.copyWith(libraryLayoutMode: mode.id),
        );
        bookRepository.seedBooks(_longList);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final scrollView = switch (mode) {
          LibraryLayoutMode.list => find.byType(LibraryListView),
          LibraryLayoutMode.grid => find.byType(LibraryGridView),
        };
        final viewport = find.descendant(
          of: scrollView,
          matching: find.byType(Scrollable),
        );
        final firstCover = find.byType(AppSourceCoverFrame).first;
        final search = tester.getRect(find.byType(SearchField));
        final header = tester.getRect(find.byType(LibraryHeader));

        expect(
          header.bottom,
          closeTo(search.bottom + kLibraryHeaderBottomPadding, .01),
        );
        expect(tester.getRect(viewport).top, closeTo(header.bottom, .01));
        expect(
          tester.getRect(firstCover).top,
          closeTo(header.bottom + kLibraryContentTopPadding, .01),
        );
        expect(tester.widget<ScrollEdgeFade>(topFade).visible, isFalse);

        await tester.drag(scrollView, const Offset(0, -120));
        await tester.pumpAndSettle();

        // The first cover has passed under the band's lower edge, where the
        // viewport clips it and the fade starts, clear of the field.
        expect(tester.getRect(firstCover).top, lessThan(header.bottom));
        expect(tester.getRect(viewport).top, closeTo(header.bottom, .01));
        expect(tester.widget<ScrollEdgeFade>(topFade).visible, isTrue);
        expect(tester.getRect(topFade).top, closeTo(header.bottom, .01));
        // A 12dp band, the same gap the content starts below it.
        expect(
          tester.getRect(topFade).top - search.bottom,
          closeTo(AppSpacing.md, .01),
        );
      });
    }
  });

  group('bottom capsule and the keyboard', () {
    const height = 844.0;
    const safeInset = 34.0;
    // The capsule's distance from the screen edge: the Scaffold's 16dp margin
    // and its 8dp lift on whichever is higher, the keyboard or the safe inset.
    double expectedCapsuleGap(double keyboard) =>
        math.max(keyboard, safeInset) +
        AppSpacing.lg +
        kLibraryFloatingActionsLift;

    Future<void> pumpPhone(WidgetTester tester, LibraryLayoutMode mode) async {
      tester.view.physicalSize = const Size(390, height);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: safeInset);
      tester.view.padding = const FakeViewPadding(bottom: safeInset);
      addTearDown(tester.view.reset);
      await preferencesService.update(
        (prefs) => prefs.copyWith(libraryLayoutMode: mode.id),
      );
      bookRepository.seedBooks(_longList);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
    }

    // One keyboard frame. dart:ui reports padding as the part of the view
    // padding the keyboard leaves uncovered.
    Future<void> setKeyboard(WidgetTester tester, double keyboard) async {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.padding = FakeViewPadding(
        bottom: math.max(0, safeInset - keyboard),
      );
      await tester.pump();
    }

    double capsuleGap(WidgetTester tester) =>
        height - tester.getRect(_capsule).bottom;

    testWidgets('rides the keyboard down to its place without dipping into '
        'the safe inset and jumping back', (tester) async {
      await pumpPhone(tester, LibraryLayoutMode.list);
      final resting = capsuleGap(tester);
      expect(resting, closeTo(expectedCapsuleGap(0), .01));

      var previous = double.infinity;
      for (final keyboard in [320.0, 200.0, 60.0, safeInset, 20, 1, 0]) {
        await setKeyboard(tester, keyboard.toDouble());
        final gap = capsuleGap(tester);
        expect(
          gap,
          closeTo(expectedCapsuleGap(keyboard.toDouble()), .01),
          reason: 'keyboard $keyboard',
        );
        expect(gap, lessThanOrEqualTo(previous + .01), reason: '$keyboard');
        expect(gap, greaterThanOrEqualTo(resting - .01), reason: '$keyboard');
        previous = gap;
      }
      expect(capsuleGap(tester), closeTo(resting, .01));

      // An opening keyboard lifts it the same way, never below its place.
      for (final keyboard in [1.0, 20.0, 60.0, 320.0]) {
        await setKeyboard(tester, keyboard);
        expect(
          capsuleGap(tester),
          closeTo(expectedCapsuleGap(keyboard), .01),
          reason: 'keyboard $keyboard',
        );
        expect(capsuleGap(tester), greaterThanOrEqualTo(resting - .01));
      }
      expect(tester.takeException(), isNull);
    });

    for (final mode in LibraryLayoutMode.values) {
      testWidgets('the last row ends 16dp above the capsule over the safe '
          'inset and the keyboard: ${mode.id}', (tester) async {
        await pumpPhone(tester, mode);
        final tiles = switch (mode) {
          LibraryLayoutMode.list => find.byType(BookLibraryListTile),
          LibraryLayoutMode.grid => find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'library-grid-',
                ),
          ),
        };
        final position = tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(LibraryBody),
                matching: find.byType(Scrollable),
              ),
            )
            .position;

        for (final keyboard in [0.0, 20.0, 320.0]) {
          await setKeyboard(tester, keyboard);
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          final lastBottom = tester
              .widgetList<Widget>(tiles)
              .map((widget) => tester.getRect(find.byWidget(widget)).bottom)
              .reduce(math.max);
          expect(
            tester.getRect(_capsule).top - lastBottom,
            closeTo(AppSpacing.lg, .01),
            reason: 'keyboard $keyboard',
          );
        }
      });
    }
  });
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance() + .05;
  final second = b.computeLuminance() + .05;
  return first > second ? first / second : second / first;
}

class _FakeArticleRepository implements ArticleRepository {
  final List<Article> _articles = [];

  void seedArticles(List<Article> articles) => _articles
    ..clear()
    ..addAll(articles);

  @override
  Future<List<LibrarySource>> getLibrarySources() async =>
      _articles.map(LibrarySource.fromArticle).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
