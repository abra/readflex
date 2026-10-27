import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_body.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:domain_models/domain_models.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';
import 'helpers/fake_fsrs_repository.dart';

final _row = find.byKey(const ValueKey('libraryPracticeRow'));
final _button = find.byKey(const ValueKey('libraryPracticeButton'));
final _badge = find.byKey(const ValueKey('libraryPracticeBadge'));
final _capsule = find.byKey(const ValueKey('libraryFloatingActions'));

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

bool _badgeVisible(WidgetTester tester) => _badge.evaluate().isNotEmpty;

/// Every entry into Practice the Library offers: the row under the search
/// field once something is saved, and the capsule button with its due
/// badge, always.
void main() {
  late FakeBookRepository bookRepository;
  late FakeCollectionRepository collectionRepository;
  late FakeFsrsRepository fsrsRepository;
  late PreferencesService preferencesService;

  setUp(() async {
    bookRepository = FakeBookRepository()..seedBooks([_book]);
    collectionRepository = FakeCollectionRepository();
    fsrsRepository = FakeFsrsRepository();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
  });

  Widget buildSubject({
    bool withReviewStore = true,
    Future<void> Function()? onPracticePressed,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
  }) => MaterialApp(
    locale: locale,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: LibraryScreen(
      bookRepository: bookRepository,
      collectionRepository: collectionRepository,
      fsrsRepository: withReviewStore ? fsrsRepository : null,
      preferencesService: preferencesService,
      onSourcePressed: (_, {onSourceOpened, onReadingPositionSaved}) async {},
      onAddPressed:
          ({required onImported, entry = LibraryImportEntry.menu}) async {},
      onPracticePressed: onPracticePressed,
    ),
  );

  group('LibraryScreen', () {
    testWidgets('without a Practice destination there is no entry', (
      tester,
    ) async {
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(_capsule, findsOneWidget);
      expect(_button, findsNothing);
      expect(_row, findsNothing);
    });

    testWidgets('without a review store the capsule still opens Practice', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        buildSubject(
          withReviewStore: false,
          onPracticePressed: () async => opened++,
        ),
      );
      await tester.pumpAndSettle();

      expect(_row, findsNothing);
      expect(_badgeVisible(tester), isFalse);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('nothing saved: the button without a badge, no row', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      expect(_button, findsOneWidget);
      expect(_badgeVisible(tester), isFalse);
      expect(_row, findsNothing);
      expect(fsrsRepository.getStatsCallCount, 1);
    });

    testWidgets('cards due: the row counts them, the badge shows the number', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _row, matching: find.text('2 cards due today')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row,
          matching: find.text('1 word · 1 highlight'),
        ),
        findsOneWidget,
      );
      // The row leads the content under the header, inside the gutters.
      expect(
        find.descendant(of: find.byType(LibraryBody), matching: _row),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(LibraryHeader), matching: _row),
        findsNothing,
      );
      final rowRect = tester.getRect(_row);
      expect(
        rowRect.top,
        closeTo(
          tester.getBottomLeft(find.byType(LibraryHeader)).dy +
              kLibraryContentTopPadding,
          .01,
        ),
      );
      expect(rowRect.left, closeTo(AppSpacing.lg, .01));
      expect(rowRect.right, closeTo(390 - AppSpacing.lg, .01));
      expect(
        rowRect.bottom,
        lessThan(tester.getTopLeft(find.text(_book.title)).dy),
      );
      expect(_badgeVisible(tester), isTrue);
      expect(
        find.descendant(of: _badge, matching: find.text('2')),
        findsOneWidget,
      );
      // Screen readers hear the count on the button, not only the badge.
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(_button),
        isSemantics(
          tooltip: 'Practice',
          value: '2 cards due today',
          // The badge number is not read twice.
          label: '',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the badge sits on the glyph corner, ringed, in the target', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      final glyph = tester.getRect(
        find.descendant(of: _button, matching: find.byIcon(AppIcons.practice)),
      );
      final pill = tester.getRect(_badge);
      final target = tester.getRect(
        find.descendant(of: _button, matching: find.byType(IconButton)),
      );
      // Its end and top are 10dp past the glyph's corner: a one-digit pill
      // (20dp wide with real fonts; the test font draws every glyph as a
      // full em square, so it is wider here) is centred on that corner. It
      // stays inside the 48dp target.
      expect(pill.right, closeTo(glyph.right + 10, .5));
      expect(pill.center.dy, closeTo(glyph.top, .5));
      expect(pill.height, 20);
      expect(pill.width, greaterThanOrEqualTo(20));
      expect(target.contains(pill.topLeft), isTrue);
      expect(target.contains(pill.bottomRight), isTrue);
      // A ring in the capsule's colour separates it from the strokes.
      final decoration =
          tester.widget<DecoratedBox>(_badge).decoration as ShapeDecoration;
      final shape = decoration.shape as StadiumBorder;
      expect(shape.side.width, 2);
      expect(shape.side.color, AppTheme.light().colorScheme.surface);
      expect(decoration.color, AppTheme.light().colorScheme.primary);
    });

    testWidgets('in RTL the badge sits on the top-start corner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(
        buildSubject(
          onPracticePressed: () async {},
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      final glyph = tester.getRect(
        find.descendant(of: _button, matching: find.byIcon(AppIcons.practice)),
      );
      final pill = tester.getRect(_badge);
      expect(pill.left, closeTo(glyph.left - 10, .5));
      expect(pill.center.dy, closeTo(glyph.top, .5));
    });

    testWidgets('counts past 99 show as 99+', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fsrsRepository.stats = reviewStats(words: 150, highlights: 0, due: 150);
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      expect(find.descendant(of: _badge, matching: find.text('99+')), findsOne);
      expect(
        find.descendant(of: _badge, matching: find.text('150')),
        findsNothing,
      );
      // Spoken in full.
      final semantics = tester.getSemantics(_button);
      expect(semantics.value, '150 cards due today');
      // A wider count keeps its end on the corner and grows inwards, so it
      // stays within the target instead of reaching for "+".
      final glyph = tester.getRect(
        find.descendant(of: _button, matching: find.byIcon(AppIcons.practice)),
      );
      final pill = tester.getRect(_badge);
      final target = tester.getRect(
        find.descendant(of: _button, matching: find.byType(IconButton)),
      );
      expect(pill.right, closeTo(glyph.right + 10, .5));
      expect(pill.left, lessThan(glyph.left));
      expect(pill.top, greaterThanOrEqualTo(target.top));
      expect(pill.right, lessThanOrEqualTo(target.right));
    });

    testWidgets('all reviewed: a quiet row with the totals, no badge', (
      tester,
    ) async {
      fsrsRepository.stats = reviewStats(words: 12, highlights: 3);
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _row, matching: find.text('All caught up')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row,
          matching: find.text('12 words · 3 highlights'),
        ),
        findsOneWidget,
      );
      expect(_badgeVisible(tester), isFalse);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(_button),
        isSemantics(tooltip: 'Practice', isButton: true, hasTapAction: true),
      );
      expect(tester.getSemantics(_button).value, isEmpty);
      semantics.dispose();
    });

    testWidgets('the row and the button open Practice, then reload counts', (
      tester,
    ) async {
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      var opened = 0;
      await tester.pumpWidget(
        buildSubject(
          onPracticePressed: () async {
            opened++;
            // A session reviewed everything while Practice was open.
            fsrsRepository.stats = reviewStats(words: 1, highlights: 1);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(fsrsRepository.getStatsCallCount, 1);

      await tester.tap(_row);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(fsrsRepository.getStatsCallCount, 2);
      expect(find.text('All caught up'), findsOneWidget);
      expect(_badgeVisible(tester), isFalse);

      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 1);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(opened, 2);
      expect(find.text('All caught up'), findsOneWidget);
      expect(_badgeVisible(tester), isFalse);
    });

    testWidgets('the row keeps the last counts when a reload fails', (
      tester,
    ) async {
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(
        buildSubject(
          onPracticePressed: () async => fsrsRepository.shouldThrow = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.text('2 cards due today'), findsOneWidget);
      expect(find.text(_book.title), findsOneWidget);
    });

    testWidgets('a search or a collection hides the row with the band', (
      tester,
    ) async {
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();
      expect(_row, findsOneWidget);

      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(_book.title), findsOneWidget);
      expect(_row, findsNothing);
      expect(_button, findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(_row, findsOneWidget);
    });

    testWidgets('selecting hides the capsule and keeps the row', (
      tester,
    ) async {
      fsrsRepository.stats = reviewStats(words: 1, highlights: 1, due: 2);
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      await tester.longPress(find.text(_book.title));
      await tester.pumpAndSettle();
      expect(_button, findsNothing);
      expect(_row, findsOneWidget);
    });

    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('200% text at 320 wide fits without overflow: $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        fsrsRepository.stats = reviewStats(words: 12, highlights: 3, due: 15);
        await tester.pumpWidget(
          buildSubject(
            onPracticePressed: () async {},
            locale: locale,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_row, findsOneWidget);
        expect(_button, findsOneWidget);
        final capsule = tester.getRect(_capsule);
        expect(capsule.left, greaterThanOrEqualTo(AppSpacing.lg));
        expect(capsule.right, lessThanOrEqualTo(320 - AppSpacing.lg));
        final row = tester.getRect(_row);
        expect(row.left, closeTo(AppSpacing.lg, .01));
        expect(row.right, closeTo(320 - AppSpacing.lg, .01));
        // The row scrolls with the rows: the first source is a drag away.
        // The search field is a Scrollable too: drag the content.
        await tester.drag(
          find
              .descendant(
                of: find.byType(LibraryBody),
                matching: find.byType(Scrollable),
              )
              .first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(find.text(_book.title), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('LibraryBloc', () {
    Future<LibraryState> load(LibraryBloc bloc) {
      final loaded = bloc.stream.firstWhere(
        (state) => state.status != LibraryStatus.loading,
      );
      bloc.add(const LibraryLoadRequested());
      return loaded;
    }

    test('reads the review counts with the sources', () async {
      fsrsRepository.stats = reviewStats(words: 2, highlights: 3, due: 4);
      final bloc = LibraryBloc(
        bookRepository: bookRepository,
        fsrsRepository: fsrsRepository,
      );
      addTearDown(bloc.close);

      final state = await load(bloc);

      expect(state.status, LibraryStatus.success);
      expect(
        state.practice,
        const LibraryPracticeSummary(words: 2, highlights: 3, due: 4),
      );
      expect(state.practice!.isEmpty, isFalse);
      expect(
        const LibraryPracticeSummary(words: 0, highlights: 0, due: 0).isEmpty,
        isTrue,
      );
    });

    test('without a review store the counts stay null', () async {
      final bloc = LibraryBloc(bookRepository: bookRepository);
      addTearDown(bloc.close);

      final state = await load(bloc);

      expect(state.status, LibraryStatus.success);
      expect(state.practice, isNull);
    });

    test('a failed count read keeps the sources and the last counts', () async {
      fsrsRepository.stats = reviewStats(words: 2, highlights: 3, due: 4);
      final bloc = LibraryBloc(
        bookRepository: bookRepository,
        fsrsRepository: fsrsRepository,
      );
      addTearDown(bloc.close);
      final first = await load(bloc);
      expect(first.practice, isNotNull);

      fsrsRepository.shouldThrow = true;
      // Nothing changes, so no state is emitted: wait for the reload itself.
      final done = Completer<void>();
      bloc.add(LibraryRefreshRequested(completer: done));
      await done.future;

      expect(fsrsRepository.getStatsCallCount, 2);
      expect(bloc.state.status, LibraryStatus.success);
      expect(bloc.state.sources.map((source) => source.id), [_book.id]);
      expect(bloc.state.practice, first.practice);
    });

    test('a count read failure on the first load leaves it null', () async {
      fsrsRepository.shouldThrow = true;
      final bloc = LibraryBloc(
        bookRepository: bookRepository,
        fsrsRepository: fsrsRepository,
      );
      addTearDown(bloc.close);

      final state = await load(bloc);

      expect(state.status, LibraryStatus.success);
      expect(state.practice, isNull);
    });
  });
}
