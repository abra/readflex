import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_navigation_bar.dart';
import 'package:reader/src/reader_search_panel.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
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
    await tester.tap(find.bySemanticsLabel('Clear search'));
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
          for (final element in find.byType(IconButton).evaluate()) {
            final button = element.widget as IconButton;
            final ink = tester.widget<InkWell>(
              find.descendant(
                of: find.byWidget(button),
                matching: find.byType(InkWell),
              ),
            );
            expect(ink.customBorder, isA<CircleBorder>());
            for (final states in [
              <WidgetState>{},
              {WidgetState.disabled},
              {WidgetState.pressed},
              {WidgetState.focused},
              {WidgetState.hovered},
            ]) {
              expect(
                button.style?.backgroundColor?.resolve(states),
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

  testWidgets(
    'text actions dim on press without painting a rectangular overlay',
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
        final rect = tester.getRect(action);
        final gesture = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 150));
        final ink = tester.widget<InkWell>(
          find.descendant(of: action, matching: find.byType(InkWell)),
        );
        expect(
          ink.overlayColor!.resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        expect(ink.splashFactory, NoSplash.splashFactory);
        final content = find.descendant(
          of: action,
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(content).opacity, lessThan(1));
        expect(tester.getRect(action), rect);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.widget<Opacity>(content).opacity, 1);
        Focus.of(tester.element(content)).requestFocus();
        await tester.pumpAndSettle();
        final material = tester.widget<Material>(
          find.descendant(of: action, matching: find.byType(Material)),
        );
        expect((material.shape! as OutlinedBorder).side.width, greaterThan(0));
      }
      expect((opened, returned), (1, 1));
    },
  );

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
}

Widget _app({
  required ReaderSearchCubit cubit,
  required Widget child,
  double scale = 1,
  double inset = 0,
  bool dark = false,
  bool rtl = false,
}) {
  return MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    supportedLocales: ReadflexSupportedLocales.locales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: inset),
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
