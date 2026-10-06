import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_drawer_messages.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_navigation_bar.dart';
import 'package:reader/src/reader_search_panel.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  testWidgets('retry repeats the failed query without discarding history', (
    tester,
  ) async {
    final cubit = ReaderSearchCubit(initialRecentQueries: const ['earlier']);
    addTearDown(cubit.close);
    var requests = 0;
    Stream<ReaderSearchEvent> search(String query) {
      expect(query, 'devices');
      requests++;
      return requests == 1
          ? Stream.error(StateError('offline'))
          : Stream.value(const ReaderSearchDone(requestId: 2));
    }

    cubit.recentQuerySelected('devices', searchBook: search);
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onSearch: search,
          onResultSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(requests, 2);
    expect(cubit.state.query, 'devices');
    expect(cubit.state.recentQueries, ['earlier']);
    expect(cubit.state.errorCode, isNull);
  });
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<ReaderSearchCubit> seed(
    WidgetTester tester, {
    int count = 1000,
  }) async {
    final cubit = ReaderSearchCubit();
    addTearDown(cubit.close);
    cubit.recentQuerySelected(
      'devices',
      searchBook: (_) => Stream.fromIterable([
        ReaderSearchResults(
          requestId: 1,
          results: List.generate(
            count,
            (i) => ReaderSearchResult(
              cfi: 'cfi-$i',
              chapterTitle: 'Chapter $i',
              excerpt: const ReaderSearchExcerpt(
                pre: 'The ',
                match: 'devices',
                post: ' keep running.',
              ),
            ),
          ),
        ),
        const ReaderSearchDone(requestId: 1),
      ]),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets(
    'reopening retains query, results and scroll without searching or focusing',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final cubit = await seed(tester);
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      var searches = 0;
      await tester.pumpWidget(
        _app(
          cubit: cubit,
          child: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, shown, _) => ReaderSearchPanel(
              visible: shown,
              format: BookFormat.epub,
              pageProgressionRtl: false,
              onClose: () => visible.value = false,
              onSearch: (_) {
                searches++;
                return const Stream.empty();
              },
              onResultSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ReaderSearchResultTile).evaluate().length,
        lessThan(20),
      );
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(600);
      await tester.pumpAndSettle();
      final offset = list.controller!.offset;
      final results = cubit.state.results;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsNothing);
      visible.value = true;
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'devices');
      expect(field.focusNode!.hasFocus, isFalse);
      expect(list.controller!.offset, offset);
      expect(identical(cubit.state.results, results), isTrue);
      expect(searches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('search field stays above keyboard at $size scale=$scale', (
        tester,
      ) async {
        viewport(tester, size);
        final cubit = await seed(tester, count: 10);
        const inset = 180.0;
        await tester.pumpWidget(
          _app(
            cubit: cubit,
            scale: scale,
            inset: inset,
            child: ReaderSearchPanel(
              visible: true,
              format: BookFormat.epub,
              pageProgressionRtl: true,
              onClose: () {},
              onSearch: (_) => const Stream.empty(),
              onResultSelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = tester.getRect(find.byType(TextField));
        expect(field.bottom, lessThanOrEqualTo(size.height - inset));
        expect(field.top, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('reopening scrolls the active result into view', (tester) async {
    viewport(tester, const Size(390, 844));
    final cubit = await seed(tester);
    cubit.resultSelected(index: 600);
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, shown, _) => ReaderSearchPanel(
            visible: shown,
            format: BookFormat.epub,
            pageProgressionRtl: false,
            onClose: () => visible.value = false,
            onSearch: (_) => const Stream.empty(),
            onResultSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final active = find.byKey(const ValueKey('reader-search-result-600'));
    expect(active, findsNothing);

    visible.value = true;
    await tester.pumpAndSettle();
    expect(active, findsOneWidget);
    final list = tester.getRect(find.byType(ListView));
    final tile = tester.getRect(active);
    expect(tile.top, greaterThanOrEqualTo(list.top));
    expect(tile.bottom, lessThanOrEqualTo(list.bottom));
    expect(tester.widget<ReaderSearchResultTile>(active).selected, isTrue);

    // Reopening without an active result does not move the list.
    visible.value = false;
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    cubit.reset();
    visible.value = true;
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      offset,
    );
  });

  testWidgets('search field uses the keyboard search action', (tester) async {
    final cubit = ReaderSearchCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onSearch: (_) => const Stream.empty(),
          onResultSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).textInputAction,
      TextInputAction.search,
    );
  });

  testWidgets('result tap passes its index and exposes the active result', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final cubit = await seed(tester, count: 3);
    cubit.resultSelected(index: 1);
    int? selected;
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onSearch: (_) => const Stream.empty(),
          onResultSelected: (index) => selected = index,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('reader-search-result-1'));
    expect(tester.widget<ReaderSearchResultTile>(tile).selected, isTrue);
    // Active result fills the panel edge to edge without the themed radius.
    expect(
      tester
          .widget<ListTile>(
            find.descendant(of: tile, matching: find.byType(ListTile)),
          )
          .shape,
      const RoundedRectangleBorder(),
    );
    await tester.tap(tile);
    expect(selected, 1);
  });

  testWidgets('clearing results and history allows an empty-result query', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final cubit = await seed(tester, count: 5);
    cubit.resultSelected();
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onResultSelected: (_) {},
          onSearch: (_) => Stream.value(const ReaderSearchDone(requestId: 2)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from history'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unmatched');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(cubit.state.query, 'unmatched');
    expect(cubit.state.isLoading, isFalse);
    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets(
    'navigation controls fit large text and respect result boundaries',
    (tester) async {
      viewport(tester, const Size(320, 568));
      final cubit = await seed(tester, count: 2);
      cubit.resultSelected(
        index: 0,
        returnLocation: const ReaderSearchLocation(
          cfi: 'original',
          fraction: 0.12,
        ),
      );
      var next = 0;
      var returned = 0;
      var closed = 0;
      late double extent;
      await tester.pumpWidget(
        _app(
          cubit: cubit,
          scale: 2,
          child: Builder(
            builder: (context) {
              extent = readerSearchNavigationHeight(context, canReturn: true);
              return Align(
                alignment: Alignment.bottomCenter,
                child: ReaderSearchNavigationBar(
                  state: cubit.state,
                  onOpenSearch: () {},
                  onPrevious: () {},
                  onNext: () => next++,
                  onEndSearch: () => closed++,
                  onReturn: () => returned++,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Previous match',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Next match'));
      await tester.tap(find.byKey(const ValueKey('reader-search-return')));
      await tester.tap(find.byTooltip('End search'));
      expect((next, returned, closed), (1, 1, 1));
      expect(
        tester.getSize(find.byType(ReaderSearchNavigationBar)).height,
        extent,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'navigation spacing and unfilled buttons dark=$dark rtl=$rtl',
        (
          tester,
        ) async {
          viewport(tester, const Size(390, 844));
          final cubit = await seed(tester, count: 22);
          cubit.resultSelected(
            index: 5,
            returnLocation: const ReaderSearchLocation(
              cfi: 'origin',
              fraction: 0.12,
            ),
          );
          await tester.pumpWidget(
            _app(
              cubit: cubit,
              dark: dark,
              rtl: rtl,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ReaderSearchNavigationBar(
                  state: cubit.state,
                  onOpenSearch: () {},
                  onPrevious: () {},
                  onNext: () {},
                  onEndSearch: () {},
                  onReturn: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppPlainIconButton), findsNWidgets(3));
          for (final element in find.byType(IconButton).evaluate()) {
            final button = element.widget as IconButton;
            final ink = tester.widget<InkWell>(
              find.descendant(
                of: find.byWidget(button),
                matching: find.byType(InkWell),
              ),
            );
            expect(ink.customBorder, isA<CircleBorder>());
            // Resolve like IconButton does: widget style, then the global
            // theme, then Material's transparent default.
            final themed = IconButtonTheme.of(element).style?.backgroundColor;
            for (final states in [
              <WidgetState>{},
              {WidgetState.disabled},
              {WidgetState.pressed},
              {WidgetState.focused},
              {WidgetState.hovered},
            ]) {
              expect(
                button.style?.backgroundColor?.resolve(states) ??
                    themed?.resolve(states) ??
                    Colors.transparent,
                Colors.transparent,
              );
            }
            expect(
              tester.getSize(find.byWidget(button)),
              const Size.square(AppSizes.buttonHeight),
            );
          }
          final icon = tester.getRect(find.byIcon(AppIcons.search));
          final query = tester.getRect(find.text('devices'));
          final count = tester.getRect(find.text('6 of 22'));
          expect(rtl ? icon.left - query.right : query.left - icon.right, 12);
          expect(
            rtl ? query.right : query.left,
            rtl ? count.right : count.left,
          );
          expect(count.top - query.bottom, 4);
          expect(rtl ? 390 - icon.right : icon.left, greaterThanOrEqualTo(16));
          final returnIcon = tester.getRect(
            find.byIcon(AppIcons.returnToReading),
          );
          expect(returnIcon.left, icon.left);
          final returnLabel = tester.getRect(find.text('Back to reading'));
          final progress = tester.getRect(find.text('12%'));
          expect(
            rtl
                ? returnLabel.left - progress.right
                : progress.left - returnLabel.right,
            12,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('text actions keep the themed ink without an opacity wrapper', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final cubit = await seed(tester, count: 22);
    cubit.resultSelected(
      index: 5,
      returnLocation: const ReaderSearchLocation(
        cfi: 'origin',
        fraction: 0.12,
      ),
    );
    var opened = 0;
    var returned = 0;
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ReaderSearchNavigationBar(
            state: cubit.state,
            onOpenSearch: () => opened++,
            onPrevious: () {},
            onNext: () {},
            onEndSearch: () {},
            onReturn: () => returned++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in ['reader-search-reopen', 'reader-search-return']) {
      final action = find.byKey(ValueKey(key));
      expect(
        find.descendant(of: action, matching: find.byType(Opacity)),
        findsNothing,
      );
      final button = tester.widget<TextButton>(action);
      expect(button.style?.splashFactory, isNull);
      expect(button.style?.overlayColor, isNull);
      expect(button.style?.foregroundBuilder, isNull);
      final ink = tester.widget<InkWell>(
        find.descendant(of: action, matching: find.byType(InkWell)),
      );
      // The themed press feedback is the pressed overlay tint.
      expect(
        ink.overlayColor!.resolve({WidgetState.pressed}),
        isNot(Colors.transparent),
      );
      final rect = tester.getRect(action);
      final gesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getRect(action), rect);
      await gesture.up();
      await tester.pumpAndSettle();
    }
    for (final tooltip in ['Previous match', 'Next match', 'End search']) {
      expect(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(AppPlainIconButton),
        ),
        findsOneWidget,
      );
    }
    expect((opened, returned), (1, 1));
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final rtl in [false, true]) {
        testWidgets(
          'search content keeps 16px insets at $size scale=$scale rtl=$rtl',
          (tester) async {
            viewport(tester, size);
            final safePadding = size.width > size.height
                ? const EdgeInsets.only(left: 44, right: 24)
                : EdgeInsets.zero;
            const queries = [
              'devices',
              'A long recent query that cannot fit on a single line',
            ];
            final cubit = ReaderSearchCubit(initialRecentQueries: queries);
            addTearDown(cubit.close);
            await tester.pumpWidget(
              _app(
                cubit: cubit,
                scale: scale,
                rtl: rtl,
                safePadding: safePadding,
                child: ReaderSearchPanel(
                  visible: true,
                  format: BookFormat.epub,
                  pageProgressionRtl: false,
                  onClose: () {},
                  onResultSelected: (_) {},
                  onSearch: (_) => Stream.fromIterable([
                    const ReaderSearchResults(
                      requestId: 1,
                      results: [
                        ReaderSearchResult(
                          cfi: 'result-1',
                          chapterTitle: 'Chapter',
                          excerpt: ReaderSearchExcerpt(
                            pre: 'The ',
                            match: 'devices',
                            post: ' keep running.',
                          ),
                        ),
                      ],
                    ),
                    const ReaderSearchDone(requestId: 1),
                  ]),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final field = tester.getRect(find.byType(SearchField));
            final heading = tester.getRect(find.text('Recent searches'));
            final panelTitle = tester.getRect(find.text('Search'));
            final close = tester.getRect(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Close',
              ),
            );
            final closeIcon = tester.getRect(find.byIcon(AppIcons.close));
            expect(field.left, safePadding.left + 16);
            expect(field.right, size.width - safePadding.right - 16);
            expect(heading.left, field.left);
            expect(heading.right, field.right);
            expect(
              rtl ? panelTitle.right : panelTitle.left,
              rtl ? field.right : field.left,
            );
            expect(
              rtl ? closeIcon.left : closeIcon.right,
              rtl ? field.left : field.right,
            );
            expect(close.size, const Size.square(48));
            for (final query in queries) {
              final row = find.ancestor(
                of: find.text(query),
                matching: find.byType(ListTile),
              );
              final clock = tester.getRect(
                find.descendant(of: row, matching: find.byIcon(AppIcons.clock)),
              );
              final title = tester.getRect(find.text(query));
              final remove = tester.getRect(
                find.descendant(of: row, matching: find.byType(IconButton)),
              );
              final removeIcon = tester.getRect(
                find.descendant(
                  of: row,
                  matching: find.byIcon(AppIcons.delete),
                ),
              );
              expect(
                rtl ? clock.right : clock.left,
                rtl ? field.right : field.left,
              );
              expect(
                rtl ? removeIcon.left : removeIcon.right,
                rtl ? field.left : field.right,
              );
              expect(
                rtl ? clock.left - title.right : title.left - clock.right,
                greaterThanOrEqualTo(AppSpacing.sm),
              );
              expect(
                rtl ? title.left - remove.right : remove.left - title.right,
                greaterThanOrEqualTo(AppSpacing.sm),
              );
              expect(remove.width, greaterThanOrEqualTo(48));
              expect(remove.height, greaterThanOrEqualTo(48));
              expect(remove.center.dx, close.center.dx);
              expect(removeIcon.size, closeIcon.size);
              expect(removeIcon.center.dx, closeIcon.center.dx);
              expect(remove.left, greaterThanOrEqualTo(safePadding.left));
              expect(
                remove.right,
                lessThanOrEqualTo(size.width - safePadding.right),
              );
            }
            await tester.tap(find.text('devices'));
            await tester.pumpAndSettle();
            final l10n = tester.element(find.byType(SearchField)).l10n;
            final matches = tester.getRect(
              find.text(l10n.readerSearchMatches(1)),
            );
            final chapter = tester.getRect(find.text('Chapter'));
            final excerpt = tester.getRect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is RichText &&
                    widget.text.toPlainText() == 'The devices keep running.',
              ),
            );
            expect(
              rtl ? matches.right : matches.left,
              rtl ? field.right : field.left,
            );
            expect(chapter.left, field.left);
            expect(chapter.right, field.right);
            expect(excerpt.left, field.left);
            expect(excerpt.right, field.right);
            expect(tester.getRect(find.byType(SearchField)), field);

            cubit.recentQuerySelected(
              'unmatched',
              searchBook: (_) =>
                  Stream.value(const ReaderSearchDone(requestId: 2)),
            );
            await tester.pumpAndSettle();
            expect(find.byType(EmptyState), findsOneWidget);
            final emptyMessage = tester.getRect(
              find.text(l10n.readerNoResultsFound),
            );
            expect(emptyMessage.left, greaterThanOrEqualTo(field.left));
            expect(emptyMessage.right, lessThanOrEqualTo(field.right));
            expect(
              emptyMessage.center.dx,
              moreOrLessEquals(field.center.dx, epsilon: 1),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('history removal does not search and the clock opens its query', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final cubit = ReaderSearchCubit(initialRecentQueries: ['devices', 'power']);
    addTearDown(cubit.close);
    final searches = <String>[];
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onResultSelected: (_) {},
          onSearch: (query) {
            searches.add(query);
            return Stream.value(const ReaderSearchDone(requestId: 1));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.close), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip('Remove from history'),
        matching: find.byIcon(AppIcons.delete),
      ),
      findsNWidgets(2),
    );
    await tester.tap(find.byTooltip('Remove from history').last);
    await tester.pumpAndSettle();
    expect(cubit.state.recentQueries, ['devices']);
    expect(searches, isEmpty);
    await tester.tap(find.byIcon(AppIcons.clock));
    await tester.pumpAndSettle();
    expect(searches, ['devices']);
    expect(cubit.state.query, 'devices');
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search panel close and history controls have circular feedback',
    (
      tester,
    ) async {
      viewport(tester, const Size(390, 844));
      final cubit = ReaderSearchCubit(initialRecentQueries: ['devices']);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _app(
          cubit: cubit,
          child: ReaderSearchPanel(
            visible: true,
            format: BookFormat.epub,
            pageProgressionRtl: false,
            onClose: () {},
            onResultSelected: (_) {},
            onSearch: (_) => const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final tooltip in ['Close', 'Remove from history']) {
        final ink = tester.widget<InkWell>(
          find.descendant(
            of: find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == tooltip,
            ),
            matching: find.byType(InkWell),
          ),
        );
        expect(ink.customBorder, isA<CircleBorder>());
      }
    },
  );
  testWidgets('search placeholders use the shared states', (tester) async {
    viewport(tester, const Size(390, 844));
    final cubit = ReaderSearchCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onResultSelected: (_) {},
          onSearch: (_) => Stream.value(const ReaderSearchDone(requestId: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(SearchField)).l10n;
    final prompt = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(prompt.compact, isTrue);
    expect(prompt.icon, isNull);
    expect(
      find.text(readerSearchPromptMessage(l10n, BookFormat.epub)),
      findsOneWidget,
    );
    expect(find.byType(ErrorState), findsNothing);

    final fieldPadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byType(SearchField),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(fieldPadding.padding, const EdgeInsets.all(AppSpacing.lg));

    cubit.recentQuerySelected(
      'unmatched',
      searchBook: (_) => Stream.value(const ReaderSearchDone(requestId: 2)),
    );
    await tester.pumpAndSettle();
    final empty = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(empty.compact, isTrue);
    expect(empty.icon, AppIcons.searchOff);
    expect(empty.message, l10n.readerNoResultsFound);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search header close uses the default 20dp glyph', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final cubit = ReaderSearchCubit(initialRecentQueries: ['devices']);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        child: ReaderSearchPanel(
          visible: true,
          format: BookFormat.epub,
          pageProgressionRtl: false,
          onClose: () {},
          onResultSelected: (_) {},
          onSearch: (_) => const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final close = find.byTooltip('Close');
    expect(tester.getSize(close), const Size.square(AppSizes.buttonHeight));
    final closeIcon = tester.getRect(find.byIcon(AppIcons.close));
    expect(closeIcon.size, const Size.square(AppIconSize.sm));
    expect(390 - closeIcon.right, AppSpacing.lg);
    final removeIcon = tester.getRect(find.byIcon(AppIcons.delete));
    expect(removeIcon.size, const Size.square(AppIconSize.sm));
    expect(removeIcon.right, closeIcon.right);
  });

  for (final rtl in [false, true]) {
    testWidgets('hidden search panel slides toward the leading edge rtl=$rtl', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844));
      final cubit = ReaderSearchCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _app(
          cubit: cubit,
          rtl: rtl,
          child: ReaderSearchPanel(
            visible: false,
            format: BookFormat.epub,
            pageProgressionRtl: false,
            onClose: () {},
            onResultSelected: (_) {},
            onSearch: (_) => const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, Offset(rtl ? 1 : -1, 0));
      expect(slide.duration, AppMotion.short);
    });
  }

  testWidgets('search panel settles in one frame under reduced motion', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final cubit = ReaderSearchCubit();
    addTearDown(cubit.close);
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      _app(
        cubit: cubit,
        disableAnimations: true,
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, shown, _) => ReaderSearchPanel(
            visible: shown,
            format: BookFormat.epub,
            pageProgressionRtl: false,
            onClose: () {},
            onResultSelected: (_) {},
            onSearch: (_) => const Stream.empty(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
    visible.value = true;
    await tester.pump();
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    expect(
      tester
          .getRect(
            find
                .descendant(
                  of: find.byType(ReaderSearchPanel),
                  matching: find.byType(Material),
                )
                .first,
          )
          .left,
      0,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}

Widget _app({
  required ReaderSearchCubit cubit,
  required Widget child,
  double scale = 1,
  double inset = 0,
  EdgeInsets safePadding = EdgeInsets.zero,
  bool dark = false,
  bool rtl = false,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    supportedLocales: ReadflexSupportedLocales.locales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: inset),
        padding: safePadding,
        viewPadding: safePadding,
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    ),
    home: BlocProvider.value(
      value: cubit,
      child: Scaffold(resizeToAvoidBottomInset: false, body: child),
    ),
  );
}
