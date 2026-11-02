import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_body.dart';
import 'package:library_feature/src/library_grid_tile.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_content_scroll_view.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_practice_button.dart';
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
final _add = find.byKey(const ValueKey('libraryAddButton'));

final _book = Book(
  id: 'b-1',
  title: 'Flutter in Action',
  filePath: '/books/flutter.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);

bool _badgeVisible(WidgetTester tester) => _badge.evaluate().isNotEmpty;

/// Every entry into Practice the Library offers: the row under the search
/// field once something is saved, and the floating button with its due
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
    void setPhone(WidgetTester tester, {double height = 568}) {
      tester.view.physicalSize = Size(320, height);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
    }

    void setKeyboard(WidgetTester tester, double height) {
      tester.view.viewInsets = FakeViewPadding(bottom: height);
      tester.view.padding = FakeViewPadding(
        bottom: height < 34 ? 34 - height : 0,
      );
    }

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

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets(
        'Practice is a plain target above + without moving its anchor: $locale',
        (
          tester,
        ) async {
          setPhone(tester);
          fsrsRepository.stats = reviewStats(words: 12, highlights: 3, due: 15);
          await tester.pumpWidget(
            buildSubject(
              locale: locale,
              textScaler: const TextScaler.linear(2),
            ),
          );
          await tester.pumpAndSettle();
          final originalAdd = tester.getRect(_add);
          await tester.pumpWidget(
            buildSubject(
              onPracticePressed: () async {},
              locale: locale,
              textScaler: const TextScaler.linear(2),
            ),
          );
          await tester.pumpAndSettle();
          final updatedAdd = tester.getRect(_add);
          expect(updatedAdd.left, closeTo(originalAdd.left, 0.01));
          expect(updatedAdd.top, closeTo(originalAdd.top, 0.01));
          expect(updatedAdd.width, closeTo(originalAdd.width, 0.01));
          expect(updatedAdd.height, closeTo(originalAdd.height, 0.01));
          expect(
            find.descendant(of: _capsule, matching: _button),
            findsNothing,
          );
          final iconButton = tester.widget<IconButton>(
            find.descendant(of: _button, matching: find.byType(IconButton)),
          );
          expect(
            iconButton.style!.backgroundColor!.resolve({}),
            Colors.transparent,
          );
          final glyph = tester.widget<Icon>(
            find.descendant(
              of: _button,
              matching: find.byIcon(AppIcons.practiceFloating),
            ),
          );
          expect(glyph.size, 32);
          expect(glyph.shadows, isNotEmpty);
          expect(
            tester.getSize(find.byIcon(AppIcons.practiceFloating)),
            const Size.square(32),
          );
          expect(_badge, findsOneWidget);

          for (final keyboard in [0.0, 20.0, 240.0, 1.0, 0.0]) {
            setKeyboard(tester, keyboard);
            await tester.pumpAndSettle();
            final practice = tester.getRect(_button);
            final capsule = tester.getRect(_capsule);
            final add = tester.getRect(_add);
            expect(practice.width, closeTo(48, 0.01));
            expect(practice.height, closeTo(48, 0.01));
            expect(practice.center.dx, closeTo(add.center.dx, 0.01));
            expect(capsule.top - practice.bottom, closeTo(AppSpacing.sm, 0.01));
            expect(
              capsule.height,
              closeTo(kLibraryFloatingActionsHeight, 0.01),
            );
            expect(
              568 - capsule.bottom,
              closeTo(
                (keyboard > 34 ? keyboard : 34) +
                    16 +
                    kLibraryFloatingActionsLift,
                0.01,
              ),
            );
            expect(practice.left, greaterThanOrEqualTo(AppSpacing.lg - 0.01));
            expect(
              practice.right,
              lessThanOrEqualTo(320 - AppSpacing.lg + 0.01),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }

    for (final mode in LibraryLayoutMode.values) {
      testWidgets(
        'the last $mode source scrolls above the separate Practice action',
        (
          tester,
        ) async {
          setPhone(tester, height: 844);
          bookRepository.seedBooks([
            for (var i = 0; i < 12; i++)
              Book(
                id: 'book-$i',
                title: 'Book $i',
                filePath: '/books/$i.epub',
                format: BookFormat.epub,
                addedAt: DateTime(2026),
              ),
          ]);
          await preferencesService.update(
            (p) => p.copyWith(libraryLayoutMode: mode.id),
          );
          await tester.pumpWidget(
            buildSubject(
              withReviewStore: false,
              onPracticePressed: () async {},
              textScaler: const TextScaler.linear(2),
            ),
          );
          await tester.pumpAndSettle();
          final position = tester
              .state<ScrollableState>(
                find.descendant(
                  of: find.byType(LibraryContentScrollView),
                  matching: find.byType(Scrollable),
                ),
              )
              .position;
          final tiles = switch (mode) {
            LibraryLayoutMode.list => find.byType(BookLibraryListTile),
            LibraryLayoutMode.grid => find.byType(BookLibraryGridTile),
          };
          for (final keyboard in [0.0, 240.0]) {
            setKeyboard(tester, keyboard);
            await tester.pumpAndSettle();
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              tiles,
              findsWidgets,
              reason:
                  '$mode keyboard $keyboard, pixels ${position.pixels}, '
                  'max ${position.maxScrollExtent}, viewport ${position.viewportDimension}',
            );
            final lastBottom = tester
                .widgetList<Widget>(tiles)
                .map((tile) => tester.getRect(find.byWidget(tile)).bottom)
                .reduce((a, b) => a > b ? a : b);
            expect(
              tester.getTopLeft(_button).dy - lastBottom,
              closeTo(AppSpacing.lg, 0.01),
              reason: 'keyboard $keyboard',
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }

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
        find.descendant(
          of: _button,
          matching: find.byIcon(AppIcons.practiceFloating),
        ),
      );
      final pill = tester.getRect(_badge);
      final target = tester.getRect(
        find.descendant(of: _button, matching: find.byType(IconButton)),
      );
      // Its end is 8dp past the glyph's corner: a one-digit pill
      // (20dp wide with real fonts; the test font draws every glyph as a
      // full em square, so it is wider here) is centred on that corner. It
      // stays inside the 48dp target.
      expect(pill.right, closeTo(glyph.right + 8, .5));
      expect(pill.center.dy, closeTo(glyph.top + 2, .5));
      expect(pill.height, 20);
      expect(pill.width, greaterThanOrEqualTo(20));
      expect(pill.left, greaterThanOrEqualTo(target.left - 0.01));
      expect(pill.top, greaterThanOrEqualTo(target.top - 0.01));
      expect(pill.right, lessThanOrEqualTo(target.right + 0.01));
      expect(pill.bottom, lessThanOrEqualTo(target.bottom + 0.01));
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
        find.descendant(
          of: _button,
          matching: find.byIcon(AppIcons.practiceFloating),
        ),
      );
      final pill = tester.getRect(_badge);
      expect(pill.left, closeTo(glyph.left - 8, .5));
      expect(pill.center.dy, closeTo(glyph.top + 2, .5));
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
        find.descendant(
          of: _button,
          matching: find.byIcon(AppIcons.practiceFloating),
        ),
      );
      final pill = tester.getRect(_badge);
      final target = tester.getRect(
        find.descendant(of: _button, matching: find.byType(IconButton)),
      );
      expect(pill.right, closeTo(glyph.right + 8, .5));
      expect(pill.left, lessThan(glyph.left));
      expect(pill.top, greaterThanOrEqualTo(target.top));
      expect(pill.right, lessThanOrEqualTo(target.right));
    });

    testWidgets('highlights count as due only while sessions review them', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fsrsRepository.stats = reviewStats(
        words: 3,
        highlights: 2,
        due: 1,
        dueHighlights: 1,
      );
      await preferencesService.update(
        (p) => p.copyWith(practiceReviewHighlights: false),
      );
      await tester.pumpWidget(buildSubject(onPracticePressed: () async {}));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _row, matching: find.text('1 card due today')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _badge, matching: find.text('1')),
        findsOneWidget,
      );
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
        expect(capsule.left, greaterThanOrEqualTo(AppSpacing.lg - 0.01));
        expect(capsule.right, lessThanOrEqualTo(320 - AppSpacing.lg + 0.01));
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

  group('large Practice badge counts', () {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final textScale in [1.0, 2.0, 3.0]) {
        testWidgets(
          'complete count stays inside its target: $locale ${textScale}x',
          (
            tester,
          ) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final semantics = tester.ensureSemantics();
            try {
              var opened = 0;
              const counts = [9, 10, 99, 100, 1000, 1000000];
              for (final count in counts) {
                await tester.pumpWidget(
                  MaterialApp(
                    locale: locale,
                    supportedLocales: ReadflexSupportedLocales.locales,
                    localizationsDelegates:
                        ReadflexLocalizations.localizationsDelegates,
                    theme: AppTheme.light(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(textScale),
                      ),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: Center(
                        child: LibraryPracticeButton(
                          due: count,
                          onPressed: () => opened++,
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final target = tester.getRect(
                  find.descendant(
                    of: _button,
                    matching: find.byType(IconButton),
                  ),
                );
                final badge = tester.getRect(_badge);
                final label = count > 99 ? '99+' : '$count';
                final paragraph = tester.renderObject<RenderParagraph>(
                  find.descendant(
                    of: find.descendant(of: _badge, matching: find.text(label)),
                    matching: find.byType(RichText),
                  ),
                );
                final paintedLabel = MatrixUtils.transformRect(
                  paragraph.getTransformTo(null),
                  Offset.zero & paragraph.size,
                );
                expect(target.size, const Size.square(48));
                for (final bounds in [badge, paintedLabel]) {
                  expect(
                    bounds.left,
                    greaterThanOrEqualTo(target.left - 0.01),
                    reason: '$count',
                  );
                  expect(
                    bounds.right,
                    lessThanOrEqualTo(target.right + 0.01),
                    reason: '$count',
                  );
                  expect(
                    bounds.top,
                    greaterThanOrEqualTo(target.top - 0.01),
                    reason: '$count',
                  );
                  expect(
                    bounds.bottom,
                    lessThanOrEqualTo(target.bottom + 0.01),
                    reason: '$count',
                  );
                  expect(bounds.left, greaterThanOrEqualTo(0));
                  expect(bounds.right, lessThanOrEqualTo(320));
                  expect(bounds.top, greaterThanOrEqualTo(0));
                  expect(bounds.bottom, lessThanOrEqualTo(568));
                }
                expect(
                  paintedLabel.left,
                  greaterThanOrEqualTo(badge.left - 0.01),
                );
                expect(
                  paintedLabel.right,
                  lessThanOrEqualTo(badge.right + 0.01),
                );
                expect(
                  paintedLabel.top,
                  greaterThanOrEqualTo(badge.top - 0.01),
                );
                expect(
                  paintedLabel.bottom,
                  lessThanOrEqualTo(badge.bottom + 0.01),
                );
                expect(paragraph.didExceedMaxLines, isFalse);
                expect(paragraph.textDirection, TextDirection.ltr);
                final l10n = tester.element(_button).l10n;
                expect(
                  tester.getSemantics(_button).value,
                  l10n.practiceDueToday(count),
                );
                await tester.tap(_button);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
              expect(opened, counts.length);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
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
