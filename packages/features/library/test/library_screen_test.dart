import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_grid_view.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';

const double _collectionSourcesMaxHeightForTest = 260;

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  author: 'Eric Windmill',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

final _secondBook = Book(
  id: 'b-2',
  title: 'Clean Architecture',
  author: 'Robert C. Martin',
  filePath: '/books/clean-architecture.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 2),
);

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
    LibraryImportLauncher? onAddPressed,
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
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: onAddPressed ?? ({required onImported}) async {},
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
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.ensureVisible(find.text(_secondBook.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_secondBook.title));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
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

    void expectReadableSelection(int count) {
      final tiles = tester
          .widgetList<ListTile>(
            find.descendant(
              of: find.byType(ActionBottomSheetLayout).last,
              matching: find.byType(ListTile),
            ),
          )
          .where((tile) => tile.selected);
      expect(tiles, hasLength(count));
      for (final tile in tiles) {
        final foreground = tile.selectedColor!.computeLuminance();
        final background = theme.colorScheme.surface.computeLuminance();
        expect(
          (foreground + 0.05) / (background + 0.05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }

    expectReadableSelection(2);
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
    ).computeLuminance();
    expect(
      (label.style!.color!.computeLuminance() + 0.05) / (background + 0.05),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    'display opens a separate language picker and returns to settings',
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
          of: find.byType(BottomSheet).last,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('libraryLanguageOption-ru')));
      await tester.pumpAndSettle();
      expect(preferencesService.current.locale.languageCode, 'ru');
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
        onAddPressed: ({required onImported}) async {
          imported = onImported;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
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

  testWidgets('empty search resets filters without reloading the library', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comics'));
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text(_book.title), findsOneWidget);
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

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.bySemanticsLabel('1 item'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('library item count stays compact with localized semantics', (
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

      expect(find.text('Библиотека'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('2 элемента'), findsNothing);
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
        of: find.byType(BottomSheet).last,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(preferencesService.current.locale, const Locale('ru'));
    expect(find.text('Библиотека'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
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
    expect(hindiRect.top, greaterThan(englishRect.top));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('libraryLanguageOption-en')),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
  });

  for (final profile in [
    (name: 'phone', size: const Size(390, 844), locale: 'en', scale: 1.0),
    (name: 'RTL phone', size: const Size(390, 844), locale: 'ar', scale: 1.0),
    (name: 'large text', size: const Size(390, 844), locale: 'en', scale: 2.0),
    (
      name: 'tall tablet',
      size: const Size(800, 1400),
      locale: 'en',
      scale: 1.0,
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

      final sheet = find.byType(BottomSheet).last;
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
      expect(listRect.left - sheetRect.left, AppSpacing.xl);
      expect(sheetRect.right - listRect.right, AppSpacing.xl);
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
      if (profile.name == 'tall tablet') {
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
    final displayButtonRect = tester.getRect(
      find.byKey(const ValueKey('libraryHeaderDisplayButton')),
    );

    expect(
      displayButtonRect.right,
      closeTo(scaffoldRect.right - AppSpacing.lg, 1),
    );
  });

  testWidgets('shows offline status next to Library title', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject(isOffline: true));
    await tester.pump();

    final titleRect = tester.getRect(find.text('Library'));
    final statusRect = tester.getRect(find.text('offline'));
    final statusText = tester.widget<Text>(find.text('offline'));

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(statusRect.left, greaterThan(titleRect.right));
    expect(statusText.style?.color, AppTheme.light().ext.warning);
  });

  testWidgets('hides offline status while reserving header space', (
    tester,
  ) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final statusOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('offline'),
        matching: find.byType(Opacity),
      ),
    );

    expect(statusOpacity.opacity, 0);
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
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
          onAddPressed: ({required onImported}) async {},
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

    expect(find.text('Library'), findsOneWidget);
    expect(searchFocusNode.hasFocus, isFalse);
    expect(searchFocusNode.canRequestFocus, isTrue);
  });

  testWidgets('shows filter segments', (tester) async {
    bookRepository.seedBooks([_book]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Comics'), findsOneWidget);
  });

  testWidgets('shows FAB', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('keeps FAB above the bottom edge', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final paddingAncestors = find.ancestor(
      of: find.byIcon(AppIcons.add),
      matching: find.byType(Padding),
    );
    final hasBottomLift = paddingAncestors.evaluate().any((element) {
      final padding = (element.widget as Padding).padding;
      return padding == const EdgeInsetsDirectional.only(bottom: AppSpacing.sm);
    });

    expect(hasBottomLift, isTrue);
  });

  testWidgets('FAB guards against double-tap while import is in-flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    var invocations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: ({required onImported}) async {
            invocations++;
            await gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(
      invocations,
      1,
      reason: 'second tap during in-flight import must be ignored',
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  // Visual counterpart to the guard test above. The behavioural guard
  // alone (re-entry check inside the handler) made the second tap a
  // silent no-op, but the FAB stayed visually enabled — confusing UX
  // and the fragility flagged by audit ("if UI ever depends on the
  // flag, it would silently desync"). Now `_addInFlight` is mutated
  // through setState and passed down as a nullable onPressed, so
  // FloatingActionButton renders greyed-out for the duration of the
  // import.
  testWidgets('FAB renders disabled while import is in-flight', (tester) async {
    final gate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryScreen(
          bookRepository: bookRepository,
          collectionRepository: collectionRepository,
          preferencesService: preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: ({required onImported}) async {
            await gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    // Before the tap: FAB is enabled.
    final initialFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(initialFab.onPressed, isNotNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // While the awaited onAddPressed parks on the gate, the FAB's
    // onPressed must be null — Material renders that state as disabled.
    final inFlightFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(inFlightFab.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();

    // After the import resolves the FAB returns to its enabled state.
    final settledFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(settledFab.onPressed, isNotNull);
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
          onAddPressed: ({required onImported}) async {},
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
          onAddPressed: ({required onImported}) async {},
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

    expect(find.byType(FloatingActionButton), findsNothing);
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dune'));
    await tester.pumpAndSettle();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsNothing);
    expect(find.text('Dune'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();

    expect(find.text('Flutter in Action'), findsOneWidget);
    expect(find.text('Domain-Driven Design'), findsOneWidget);
  });

  testWidgets(
    'collection scope sheet shows favourites without permanent section',
    (
      tester,
    ) async {
      bookRepository.seedBooks([_book]);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(AppIcons.collection));
      await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final sheet = find.byType(ActionBottomSheetLayout);
    final searchField = find.descendant(
      of: sheet,
      matching: find.byType(TextField),
    );
    final favouritesRow = find.byKey(
      const ValueKey('collectionScopeRow-favourites-readflex:favourites'),
    );

    expect(favouritesRow, findsOneWidget);
    expect(find.text('Избранное'), findsOneWidget);
    expect(find.text('Favourites'), findsNothing);

    await tester.enterText(searchField, 'избр');
    await tester.pumpAndSettle();

    expect(favouritesRow, findsOneWidget);
    expect(find.text('Избранное'), findsOneWidget);

    await tester.tap(favouritesRow);
    await tester.pumpAndSettle();

    expect(find.text('Избранное'), findsOneWidget);
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

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
        matching: find.bySemanticsLabel('Clear search'),
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final sheet = find.byType(ActionBottomSheetLayout);
    final fadeStack = find.descendant(
      of: sheet,
      matching: find.byType(ScrollEdgeFadeStack),
    );

    final sheetWidget = tester.widget<ActionBottomSheetLayout>(sheet);

    expect(find.byType(AppBottomSafeArea), findsNothing);
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
      const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
    );
  });

  testWidgets('collection scope rows do not show pressed overlay', (
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

    final manualRow = find.byKey(
      const ValueKey('collectionScopeRow-manual-collection-1'),
    );
    final rowInkWell = tester.widget<InkWell>(
      find.ancestor(of: manualRow, matching: find.byType(InkWell)),
    );

    expect(
      rowInkWell.overlayColor?.resolve({WidgetState.pressed}),
      Colors.transparent,
    );
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();

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

    final sheet = find.byType(ActionBottomSheetLayout);
    final visibleGapBelowAuthor =
        tester.getBottomLeft(sheet).dy - tester.getBottomLeft(authorRow).dy;
    expect(visibleGapBelowAuthor, greaterThanOrEqualTo(AppSpacing.lg));
  });

  for (final closeMethod in ['cancel', 'close', 'back']) {
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
      await tester.tap(find.byIcon(AppIcons.collection));
      await tester.pumpAndSettle();
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
      Future<void> close() async {
        switch (closeMethod) {
          case 'cancel':
            await tester.tap(find.text('Cancel'));
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
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

    expect(tester.getSize(sheet).height, lessThan(sheetHeightBeforeRemoval));
    expect(
      tester.getTopLeft(saveFinder).dy,
      closeTo(saveTopBeforeRemoval, 0.1),
    );

    expect(
      find.descendant(of: sheet, matching: find.text('Flutter in Action')),
      findsNothing,
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
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

    final listAreaTop = tester.getBottomLeft(countLabel).dy + AppSpacing.md;
    final deleteAction = find.descendant(
      of: sheet,
      matching: find.widgetWithText(TextButton, 'Delete collection'),
    );
    final listAreaBottom =
        tester.getTopLeft(deleteAction).dy - 1 - AppSpacing.lg;
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
          await tester.tap(find.byIcon(AppIcons.collection));
          await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
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

      await tester.tap(find.byIcon(AppIcons.collection));
      await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
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
      matching: find.widgetWithText(FilledButton, 'Delete'),
    );
    final messageAreaTop =
        tester.getBottomLeft(deleteHeader).dy + AppSpacing.sm;
    final messageAreaBottom =
        tester.getTopLeft(deleteButton).dy - AppSpacing.lg;
    final expectedMessageCenter = (messageAreaTop + messageAreaBottom) / 2;

    expect(deleteMessage, findsOneWidget);
    expect(
      tester.getCenter(deleteMessage).dy,
      closeTo(expectedMessageCenter, 1),
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

    await tester.tap(find.byIcon(AppIcons.collection));
    await tester.pumpAndSettle();
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

    final nameField = find.widgetWithText(TextField, 'New collection name');
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(
      tester.getCenter(nameField).dy,
      lessThan(tester.getCenter(find.text('Create')).dy),
    );
    expect(
      tester.getCenter(find.text('Cancel')).dy,
      closeTo(tester.getCenter(find.text('Create')).dy, 1),
    );

    await tester.enterText(
      nameField,
      'Dune',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(collectionRepository.addedSourceIdsByCollection, isNotEmpty);
    expect(
      collectionRepository.addedSourceIdsByCollection.values.single,
      contains(_book.id),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
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
