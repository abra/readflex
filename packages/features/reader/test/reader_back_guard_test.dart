import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_back_guard.dart';
import 'package:reader/src/reader_back_navigation.dart';
import 'package:reader/src/reader_highlight_focus_cubit.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('readerBackTargetFor', () {
    test('full-height panels win over popups and match navigation', () {
      expect(
        readerBackTargetFor(
          overlay: ReaderOverlay.toc,
          highlightPopupVisible: true,
          searchNavigating: true,
        ),
        ReaderBackTarget.tocDrawer,
      );
      expect(
        readerBackTargetFor(
          overlay: ReaderOverlay.search,
          highlightPopupVisible: true,
          searchNavigating: true,
        ),
        ReaderBackTarget.searchPanel,
      );
    });

    test('popup is dismissed before match navigation ends', () {
      expect(
        readerBackTargetFor(
          overlay: ReaderOverlay.none,
          highlightPopupVisible: true,
          searchNavigating: true,
        ),
        ReaderBackTarget.highlightPopup,
      );
      expect(
        readerBackTargetFor(
          overlay: ReaderOverlay.none,
          highlightPopupVisible: false,
          searchNavigating: true,
        ),
        ReaderBackTarget.searchNavigation,
      );
    });

    test('appearance is a modal route, so the reader itself may pop', () {
      expect(
        readerBackTargetFor(
          overlay: ReaderOverlay.appearance,
          highlightPopupVisible: false,
          searchNavigating: false,
        ),
        ReaderBackTarget.route,
      );
      expect(
        readerBackTargetFor(
          overlay: ReaderOverlay.none,
          highlightPopupVisible: false,
          searchNavigating: false,
        ),
        ReaderBackTarget.route,
      );
    });
  });

  group('ReaderBackGuard', () {
    late ReaderUiCubit ui;
    late ReaderHighlightFocusCubit focus;
    late ReaderSearchCubit search;
    final log = <String>[];

    setUp(() {
      ui = ReaderUiCubit();
      focus = ReaderHighlightFocusCubit();
      search = ReaderSearchCubit();
      log.clear();
    });
    tearDown(() async {
      await ui.close();
      await focus.close();
      await search.close();
    });

    Future<NavigatorState> pump(WidgetTester tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('home')),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: ui),
                BlocProvider.value(value: focus),
                BlocProvider.value(value: search),
              ],
              child: ReaderBackGuard(
                onCloseSearchPanel: () {
                  log.add('search');
                  ui.closeSearchDrawer();
                },
                onCloseTocDrawer: () {
                  log.add('toc');
                  ui.closeTocDrawer();
                },
                onDismissHighlightPopup: () {
                  log.add('popup');
                  focus.clear();
                },
                onEndSearch: () {
                  log.add('end');
                  search.reset();
                },
                child: const Scaffold(body: Text('reader')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('reader'), findsOneWidget);
      return navigator.currentState!;
    }

    testWidgets('Back closes Contents, then leaves the reader', (tester) async {
      final navigator = await pump(tester);
      ui.openTocDrawer();
      await tester.pumpAndSettle();
      expect(await navigator.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(log, ['toc']);
      expect(ui.state.tocDrawerVisible, isFalse);
      expect(find.text('reader'), findsOneWidget);

      expect(await navigator.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(log, ['toc']);
      expect(find.text('reader'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('Back closes the search panel first', (tester) async {
      final navigator = await pump(tester);
      ui.openSearchDrawer();
      await tester.pumpAndSettle();
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(log, ['search']);
      expect(find.text('reader'), findsOneWidget);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('reader'), findsNothing);
    });

    testWidgets('Back dismisses the saved-highlight popup only', (
      tester,
    ) async {
      final navigator = await pump(tester);
      focus.focus(
        const ReaderHighlightTap(
          highlightId: 'h1',
          position: ReaderSelectionPosition(
            left: 0,
            top: 0,
            right: 10,
            bottom: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(log, ['popup']);
      expect(focus.state.hasHighlight, isFalse);
      expect(find.text('reader'), findsOneWidget);
    });

    testWidgets('Back ends match navigation after the panel closes', (
      tester,
    ) async {
      final navigator = await pump(tester);
      search.recentQuerySelected(
        'word',
        searchBook: (_) => Stream.fromIterable([
          const ReaderSearchResults(
            requestId: 1,
            results: [
              ReaderSearchResult(
                cfi: 'cfi',
                chapterTitle: 'One',
                excerpt: ReaderSearchExcerpt(pre: '', match: 'word', post: ''),
              ),
            ],
          ),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      await tester.pumpAndSettle();
      search.resultSelected(index: 0);
      ui.openSearchDrawer();
      await tester.pumpAndSettle();
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(log, ['search']);
      expect(find.text('reader'), findsOneWidget);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(log, ['search', 'end']);
      expect(search.state.isNavigating, isFalse);
      expect(find.text('reader'), findsOneWidget);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('reader'), findsNothing);
    });
  });
}
