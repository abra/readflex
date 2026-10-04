import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/reader_test_platform.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('saved passages and bookmark undo ${profile.name}', (
      tester,
    ) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final previous = InAppWebViewPlatform.instance;
      final platform = ReaderTestPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        if (previous != null) InAppWebViewPlatform.instance = previous;
      });
      final quote = List.filled(
        6,
        'A passage connects what we read with what we already know.',
      ).join(' ');
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          await app.bookRepository.addBookmark(
            sourceId: app.book!.id,
            sourceType: SourceType.book,
            cfi: 'epubcfi(/6/${2 + i * 2})',
            content: 'Saved passage ${i + 1}: a place to return to.',
            progress: .2 * i,
            chapterTitle: 'Chapter ${i + 1}',
          );
        }
        await app.highlightRepository.addHighlight(
          sourceId: app.book!.id,
          sourceType: SourceType.book,
          text: quote,
          note: 'A note worth keeping.',
          cfiRange: 'epubcfi(/6/4)',
          chapterTitle: 'Chapter 2',
          progress: .28,
        );
        await app.highlightRepository.addHighlight(
          sourceId: app.book!.id,
          sourceType: SourceType.book,
          text: 'A short blue quote.',
          color: HighlightColor.blue,
          cfiRange: 'epubcfi(/6/6)',
          progress: .52,
        );
      });
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => ReaderScreen(
          sourceId: app.book!.id,
          serverBaseUri: Uri.parse('http://127.0.0.1:49152'),
          bookRepository: app.bookRepository,
          highlightRepository: app.highlightRepository,
          preferencesService: app.preferencesService,
          screenControlService: app.screenControlService,
          textActions: const [],
          initialSource: app.book,
        ),
        surfaceSize: profile == VisualProfile.tabletRtl
            ? const Size(390, 844)
            : null,
      );
      await waitForUi(
        tester,
        () => platform.views.any(
          (view) =>
              view.created && view.controller.handlers.containsKey('onLoadEnd'),
        ),
        description: 'WebView bridge',
      );
      platform.views
          .firstWhere((view) => view.created)
          .controller
          .handlers['onLoadEnd']!([]);
      final readerContext = tester.element(find.byType(BookReaderWebView));
      final bloc = readerContext.read<ReaderBloc>();
      await waitForUi(
        tester,
        () =>
            bloc.state.bookmarks.length == 3 &&
            bloc.state.highlights.length == 2,
        description: 'saved annotations',
      );
      final ui = readerContext.read<ReaderUiCubit>();
      final l10n = readerContext.l10n;
      bloc.add(
        ReaderTocUpdated(
          items: [
            const ReaderTocItem(
              label: 'Chapter 1',
              href: 'chapter-1',
              level: 1,
            ),
            const ReaderTocItem(
              label: 'Chapter 2',
              href: 'chapter-2',
              level: 1,
            ),
          ],
        ),
      );
      bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4)',
          progress: .28,
          chapterTitle: 'Chapter 2',
        ),
      );
      ui.openTocDrawer();
      await tester.pumpAndSettle();
      final active = tester.widget<ListTile>(
        find
            .ancestor(
              of: find.text('Chapter 2'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      expect(active.selected, isTrue);
      final foreground = (active.title! as Text).style!.color!;
      final background = active.selectedTileColor!;
      expect(background, readerContext.colors.selectedControlBackground);
      expect(foreground, readerContext.colors.selectedControlForeground);
      final paintedBackground = Color.alphaBlend(
        background,
        readerContext.colors.surface,
      );
      final a = Color.alphaBlend(
        foreground,
        paintedBackground,
      ).computeLuminance();
      final b = paintedBackground.computeLuminance();
      expect(
        a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05),
        greaterThanOrEqualTo(4.5),
      );
      await expectUiGolden(tester, profile, 'reader-active-chapter');
      await tapUi(tester, find.text(l10n.readerBookmarks));
      final deleteBookmark = find.byTooltip(l10n.readerDeleteBookmark);
      expect(
        find.descendant(
          of: deleteBookmark,
          matching: find.byIcon(AppIcons.delete),
        ),
        findsNWidgets(3),
      );
      expect(find.byIcon(AppIcons.close).hitTestable(), findsOneWidget);
      final closeIcon = tester.getRect(
        find.byIcon(AppIcons.close).hitTestable(),
      );
      final searchField = tester.getRect(
        find.byType(SearchField).hitTestable(),
      );
      final rtl = Directionality.of(readerContext) == TextDirection.rtl;
      expect(
        rtl ? closeIcon.left : closeIcon.right,
        rtl ? searchField.left : searchField.right,
      );
      final deleteButtons = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == l10n.readerDeleteBookmark,
      );
      for (final element in deleteButtons.evaluate()) {
        final button = find.byWidget(element.widget);
        final icon = tester.getRect(
          find.descendant(of: button, matching: find.byIcon(AppIcons.delete)),
        );
        expect(icon.size, closeIcon.size);
        expect(icon.center.dx, closeIcon.center.dx);
        expect(tester.getSize(button), const Size.square(48));
      }
      final next = find.text('Saved passage 2: a place to return to.');
      final before = tester.getRect(next);
      await tapUi(tester, deleteBookmark.first);
      await waitForUi(
        tester,
        () => bloc.state.bookmarkEdits.removed.length == 1,
        description: 'persisted deletion',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonUndo), findsNothing);
      final undoButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == l10n.commonUndo,
      );
      expect(undoButton, findsOneWidget);
      expect(tester.getSize(undoButton), const Size.square(48));
      final undoIcon = tester.getRect(
        find.descendant(of: undoButton, matching: find.byIcon(AppIcons.undo)),
      );
      expect(undoIcon.size, closeIcon.size);
      expect(undoIcon.center.dx, closeIcon.center.dx);
      expect(
        tester.getRect(next),
        before,
        reason: 'Undo must not move adjacent bookmarks',
      );
      await expectUiGolden(tester, profile, 'reader-bookmark-undo');
      await tapUi(tester, find.byTooltip(l10n.commonUndo));
      await waitForUi(
        tester,
        () => bloc.state.bookmarks.length == 3,
        description: 'restored bookmark',
      );
      await tester.ensureVisible(find.text(l10n.readerHighlights));
      await tapUi(tester, find.text(l10n.readerHighlights));
      final rows = find.byType(ReaderHighlightListTile);
      for (final icon in [
        AppIcons.copy,
        AppIcons.arrowLeft,
        AppIcons.arrowRight,
      ]) {
        expect(
          find.descendant(of: rows, matching: find.byIcon(icon)),
          findsNothing,
        );
      }
      await expectUiGolden(tester, profile, 'reader-highlight-list');
      await tester.ensureVisible(find.text(l10n.readerExpandHighlight));
      await tapUi(tester, find.text(l10n.readerExpandHighlight));
      expect(tester.widget<Text>(find.text(quote)).maxLines, isNull);
      await tester.ensureVisible(find.text(l10n.readerCollapseHighlight));
      await tapUi(tester, find.text(l10n.readerCollapseHighlight));
      await tester.ensureVisible(find.text(l10n.readerSearchHighlights));
      final blue = find.byTooltip(l10n.highlightColorBlue);
      await tester.ensureVisible(blue);
      await tapUi(tester, blue);
      expect(find.text(quote), findsNothing);
      expect(find.text('A short blue quote.'), findsOneWidget);
      final tile = tester.widget<ReaderHighlightListTile>(
        find.byType(ReaderHighlightListTile),
      );
      expect(tile.highlight.color, HighlightColor.blue);
      await tapUi(tester, find.text('A short blue quote.'));
      expect(ui.state.tocDrawerVisible, isFalse);
      await tester.pumpAndSettle();
      expect(
        platform.views.firstWhere((view) => view.created).controller.scripts,
        contains(contains('goToCfi("epubcfi(/6/6)")')),
      );
      expect(bloc.state.bookmarkEdits.removed, isEmpty);
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
