import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_chrome_progress_layout.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

/// The reader's bottom chrome: the full-width page slider right above the
/// capsule, with the chapter and the page label on the line under it.
void main() {
  setUpAll(loadUiFonts);
  const chapter = 'Chapter 12. The Long Road Home';
  const stripHeight = 320.0;

  for (final profile in VisualProfile.values) {
    testWidgets('reader progress row ${profile.name}', (tester) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final bloc = ReaderBloc(
        bookRepository: app.bookRepository,
        articleRepository: app.articleRepository,
        highlightRepository: app.highlightRepository,
        initialSource: app.book,
      );
      final ui = ReaderUiCubit()..showChrome();
      final selection = ReaderSelectionCubit();
      final appearance = ReaderAppearanceCubit(
        preferencesService: app.preferencesService,
        sourceId: app.book!.id,
      );
      addTearDown(bloc.close);
      addTearDown(ui.close);
      addTearDown(selection.close);
      addTearDown(appearance.close);
      // The bloc lives in the test's fake zone: its events advance with pumps.
      bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.2,
          chapterTitle: chapter,
          chapterCurrentPage: 3,
          chapterTotalPages: 16,
        ),
      );
      await tester.pump();
      expect(bloc.state.chapterTitle, chapter);
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final theme = ReaderThemePreset.paper.data;
      await pumpGoldenSurface(
        tester,
        profile,
        surfaceSize: Size(profile.size.width, stripHeight),
        (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: ui),
            BlocProvider.value(value: selection),
            BlocProvider.value(value: appearance),
          ],
          child: Scaffold(
            backgroundColor: theme.backgroundColor,
            body: Stack(
              children: [
                ReaderBottomChromeDriver(
                  readerTheme: theme,
                  onTocPressed: () {},
                  onFontPressed: () {},
                  onPageTurnPressed: () {},
                  onBookmarkPressed: () {},
                  onSearchPressed: () {},
                  onSeekFraction: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slider = tester.getRect(find.byType(Slider));
      final start = find.byKey(const ValueKey('readerProgressStartLabel'));
      final page = find.byKey(const ValueKey('readerProgressPageLabel'));
      final capsule = tester.getRect(
        find.byKey(const ValueKey('readerChromeCapsule')),
      );
      // The slider spans the row the capsule spans, minus the label inset.
      expect(slider.left, closeTo(capsule.left + AppSpacing.md, .01));
      expect(slider.right, closeTo(capsule.right - AppSpacing.md, .01));
      expect(tester.getRect(start).top, closeTo(slider.bottom, .01));
      expect(
        tester.getRect(start).left,
        closeTo(slider.left + readerProgressTrackInset, .01),
      );
      expect(
        tester.renderObject<RenderParagraph>(page).didExceedMaxLines,
        isFalse,
        reason: 'the page label never loses digits',
      );
      await expectUiGolden(tester, profile, 'reader-progress');

      await unmountUi(tester);
      // Flushes the reader's position-persistence debounce.
      await tester.pump(const Duration(seconds: 1));
    }, tags: ['golden']);
  }
}
