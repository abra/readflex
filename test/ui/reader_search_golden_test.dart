import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_navigation_bar.dart';
import 'package:reader/src/reader_search_panel.dart';
import 'package:reader_webview/reader_webview.dart';

import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('search surfaces ${profile.name}', (tester) async {
      final cubit = ReaderSearchCubit();
      addTearDown(cubit.close);
      cubit.recentQuerySelected(
        'devices',
        searchBook: (_) => Stream.fromIterable([
          ReaderSearchResults(
            requestId: 1,
            results: List.generate(
              24,
              (index) => ReaderSearchResult(
                cfi: 'result-$index',
                chapterTitle: 'Chapter ${index + 1}',
                excerpt: const ReaderSearchExcerpt(
                  pre: 'The battery supplies power to the ',
                  match: 'devices',
                  post: ', keeping them running throughout the day.',
                ),
              ),
            ),
          ),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      await tester.pump();
      cubit.resultSelected(
        index: 2,
        returnLocation: const ReaderSearchLocation(
          cfi: 'origin',
          fraction: 0.12,
        ),
      );
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: ReaderSearchPanel(
              visible: true,
              format: null,
              pageProgressionRtl: profile == VisualProfile.tabletRtl,
              onClose: () {},
              onResultSelected: (_) {},
              onSearch: (_) => const Stream.empty(),
            ),
          ),
        ),
      );
      await expectUiGolden(tester, profile, 'reader-search');
      final closePress = await tester.startGesture(
        tester.getCenter(find.byType(IconButton).first),
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'reader-search-close-pressed');
      await closePress.cancel();
      await tester.pumpAndSettle();
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => Scaffold(
          body: Align(
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
      await expectUiGolden(tester, profile, 'reader-search-navigation');
      // Capture all press states together without invoking navigation callbacks.
      final presses = <TestGesture>[];
      for (final target in [
        find.byKey(const ValueKey('reader-search-reopen')),
        find.byKey(const ValueKey('reader-search-return')),
        find.byIcon(AppIcons.chevronUp),
        find.byIcon(AppIcons.chevronDown),
        find.byIcon(AppIcons.close),
      ]) {
        presses.add(
          await tester.startGesture(
            tester.getCenter(target),
            pointer: presses.length + 1,
          ),
        );
      }
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'reader-search-navigation-pressed');
      for (final press in presses) {
        await press.cancel();
      }
      await tester.pumpAndSettle();
    }, tags: ['golden']);
  }
}
