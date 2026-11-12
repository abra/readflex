import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_result_tile.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:pagecraft/all_formats.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// An FB2 book in the real app on the native text engine (`pagecraft`): it
/// opens from the library, shows its chrome, turns pages (back with a
/// slide too), lists its contents, selects a word with the reader's
/// context panel and searches.
///
/// Opens the first `.fb2` of `--dart-define=PAGECRAFT_BOOKS=a|b` (the iOS
/// simulator reads host paths; on Android pass a path pushed with
/// `adb push`), or the app's reading fixture without one.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const books = String.fromEnvironment('PAGECRAFT_BOOKS');

  testWidgets('an FB2 reads on the native text engine in the app', (
    tester,
  ) async {
    final path = books
        .split('|')
        .where((p) => p.toLowerCase().endsWith('.fb2'))
        .firstOrNull;
    final app = await UiTestApp.create(
      withBook: path == null,
    );
    addTearDown(app.dispose);
    final String id;
    if (path == null) {
      id = 'ui-fixture-book';
    } else {
      final book = await tester.runAsync(
        () => app.bookRepository.addBook(
          sourceFile: File(path),
          title: 'FB2 on pagecraft',
          format: BookFormat.fb2,
        ),
      );
      id = book!.id;
    }
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);

    final open = Stopwatch()..start();
    await tapUi(tester, find.byKey(ValueKey('library-grid-$id')));
    await waitForUi(
      tester,
      () => find.byType(TextColumnPage).evaluate().isNotEmpty,
      description: 'the first page',
      timeout: const Duration(seconds: 45),
    );
    final openMs = open.elapsedMilliseconds;
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-text-open');

    ReaderBloc bloc() =>
        tester.element(find.byType(TextPagesView)).read<ReaderBloc>();
    final l10n = tester.element(find.byType(TextPagesView)).l10n;
    final size = tester.getSize(find.byType(TextPagesView));

    // The chrome over the page.
    await tester.tapAt(size.center(Offset.zero));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-text-chrome');
    final position = {
      'chapter': bloc().state.chapterTitle,
      'page':
          '${bloc().state.chapterCurrentPage}/${bloc().state.chapterTotalPages}',
      'book': '${bloc().state.bookCurrentPage}/${bloc().state.bookTotalPages}',
    };

    // The contents.
    await tapUi(tester, find.byTooltip(l10n.readerContents));
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-text-contents');
    await dismissSheet(tester);
    // The chrome is up: a tap on the page hides it.
    await tester.tapAt(size.center(Offset.zero));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-text-before-turns');

    // Turns.
    String place() =>
        '${bloc().state.chapterTitle}:${bloc().state.chapterCurrentPage}';
    for (var i = 0; i < 3; i++) {
      final page = place();
      await tester.fling(
        find.byType(TextPagesView),
        const Offset(-260, 0),
        1500,
      );
      await waitForUi(
        tester,
        () => place() != page,
        description: 'turn ${i + 1} from $page',
      );
      await tester.pumpAndSettle();
    }
    await takeDeviceScreenshot(binding, 'native-text-turned');

    // A tap on the left zone turns back: the previous page slides in from
    // the left. Time runs 20 times slower and only pumped frames draw, so
    // the screen holds the turn halfway while the screenshot is taken (the
    // iOS one renders the last frame drawn).
    final view = tester.getRect(find.byType(TextPagesView));
    final leavingTop = tester
        .widget<TextColumnPage>(find.byType(TextColumnPage))
        .page
        .top;
    final beforeBack = place();
    final Map<double, double> halfway;
    final framePolicy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
    timeDilation = 20;
    try {
      Future<void> wait(int ms) => tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await tester.tapAt(view.centerLeft + Offset(view.width * 0.05, 0));
      // The tap resolves, the turn starts on the next frame.
      await wait(400);
      await tester.pump();
      await wait(1500);
      await tester.pump();
      // The iOS screenshot shows the frame before the last one drawn.
      await tester.pump();
      halfway = {
        for (final element in find.byType(TextColumnPage).evaluate())
          (element.widget as TextColumnPage).page.top:
              (element.renderObject! as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx,
      };
      await takeDeviceScreenshot(binding, 'native-text-turning-back');
    } finally {
      timeDilation = 1;
      binding.framePolicy = framePolicy;
    }
    expect(halfway, hasLength(2), reason: 'both pages show mid-turn');
    final arrivingX = halfway.entries
        .firstWhere((e) => e.key != leavingTop)
        .value;
    final leavingX = halfway[leavingTop]!;
    expect(arrivingX, lessThan(view.left), reason: 'comes in from the left');
    expect(leavingX, greaterThan(view.left), reason: 'leaves to the right');
    await waitForUi(
      tester,
      () => place() != beforeBack,
      description: 'the turn back from $beforeBack',
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextColumnPage), findsOneWidget);
    final backTurn = {
      'from': beforeBack,
      'to': place(),
      'arrivingX': arrivingX.round(),
      'leavingX': leavingX.round(),
    };

    // A word low on the page (the page was reused across the turns) with
    // the reader's context panel.
    final pageFinder = find.byType(TextColumnPage).first;
    final widget = tester.widget<TextColumnPage>(pageFinder);
    final item = widget.column.items.whereType<ColumnText>().lastWhere(
      (t) =>
          t.rect.top >= widget.page.top &&
          t.rect.bottom <= widget.page.bottom &&
          t.paragraph.box.text.length > 40,
    );
    final word = item.paragraph.box.text.indexOf(' ', 10) + 2;
    final box = item.paragraph.boxesFor(word, word + 1).first.toRect();
    await tester.longPressAt(
      tester.getTopLeft(pageFinder) +
          item.rect.topLeft -
          Offset(0, widget.page.top) +
          box.center,
    );
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-text-selection');
    final selection = tester
        .element(find.byType(TextPagesView))
        .read<ReaderSelectionCubit>()
        .state;
    final selected = {
      'text': selection.selectedText,
      'context': selection.markedContextText,
      'cfi': selection.cfiRange,
    };

    // An edge tap takes the selection to the next page, as far as the
    // end of its first line; the start stays.
    final selections = tester
        .element(find.byType(TextPagesView))
        .read<ReaderSelectionCubit>();
    final beforeCarry = place();
    await tester.tapAt(Offset(size.width * 0.92, size.height * 0.25));
    await waitForUi(
      tester,
      () =>
          place() != beforeCarry &&
          selections.state.selectedText.length >
              selection.selectedText.length &&
          !selections.state.isAdjusting,
      description: 'the selection on the next page',
    );
    await tester.pumpAndSettle();
    await takeDeviceScreenshot(binding, 'native-text-selection-carried');
    final carried = selections.state.selectedText;
    expect(carried, startsWith(selection.selectedText));
    expect(selections.state.hasSelection, isTrue);
    final carriedSelection = {
      'from': beforeCarry,
      'to': place(),
      'length': carried.length,
    };
    // A tap in the middle clears it.
    await tester.tapAt(Offset(size.width / 2, 40));
    await tester.pumpAndSettle();
    expect(selections.state.hasSelection, isFalse);

    // Search.
    await tester.tapAt(size.center(Offset.zero));
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.readerSearchAction).first);
    await tester.pumpAndSettle();
    final searchWatch = Stopwatch()..start();
    await tester.enterText(find.byType(AppTextField).hitTestable(), 'the');
    await waitForUi(
      tester,
      () => find
          .byType(ReaderSearchResultTile)
          .hitTestable()
          .evaluate()
          .isNotEmpty,
      description: 'search results',
      timeout: const Duration(seconds: 30),
    );
    final firstResultsMs = searchWatch.elapsedMilliseconds;
    final searchCubit = tester
        .element(find.byType(AppTextField).hitTestable())
        .read<ReaderSearchCubit>();
    await waitForUi(
      tester,
      () => !searchCubit.state.isLoading,
      description: 'search completed',
      timeout: const Duration(seconds: 60),
    );
    final search = {
      'results': searchCubit.state.results.length,
      'firstResultsMs': firstResultsMs,
      'doneMs': searchWatch.elapsedMilliseconds,
    };
    await takeDeviceScreenshot(binding, 'native-text-search');

    final report = {
      'openMs': openMs,
      'position': position,
      'backTurn': backTurn,
      'selection': selected,
      'carriedSelection': carriedSelection,
      'search': search,
    };
    debugPrint('NATIVE TEXT $report');
    binding.reportData = {...?binding.reportData, 'nativeText': report};
    await unmountUi(tester);
  });
}
