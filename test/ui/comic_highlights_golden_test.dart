import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_page_thumbnail_cubit.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_image_highlight_preview.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:pagecraft/all_formats.dart' show FixedPagesView;

import '../support/comic_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  /// Waits until every mounted preview paints its crop, on the real event
  /// loop: the engine reads and decodes pages from the archive.
  Future<void> decodeVisiblePreviews(WidgetTester tester) async {
    final previews = find.byType(ReaderImageHighlightPreview);
    final placeholders = find.descendant(
      of: previews,
      matching: find.byIcon(AppIcons.book),
    );
    await waitForUi(
      tester,
      () => previews.evaluate().isNotEmpty && placeholders.evaluate().isEmpty,
      description: 'decoded previews',
      timeout: const Duration(seconds: 30),
    );
  }

  for (final profile in VisualProfile.values) {
    testWidgets(
      'comic highlights keep lazy previews and navigation ${profile.name}',
      (tester) async {
        final app = (await tester.runAsync(
          () => UiTestApp.create(withBook: false),
        ))!;
        addTearDown(app.dispose);
        final comic = (await tester.runAsync(() => addComicFixture(app)))!;
        final note = List.filled(
          8,
          'The two panels tell the story from different perspectives.',
        ).join(' ');
        await tester.runAsync(() async {
          // More entries than fit in any viewport. Offscreen rows must not
          // request thumbnails.
          for (var index = 0; index < 100; index++) {
            await app.highlightRepository.addImageAreaHighlight(
              sourceId: comic.id,
              sourceType: SourceType.book,
              pageIndex: (index ~/ 2) % 5,
              x: .04,
              y: index.isEven ? .03 : .52,
              width: .92,
              height: .45,
              chapterTitle: index == 99
                  ? 'The arrival - a quiet afternoon.png'
                  : 'page-${(index ~/ 2) % 5}.png',
              note: index == 99
                  ? note
                  : index.isEven
                  ? 'A quiet afternoon.'
                  : null,
              color: index >= 98 ? HighlightColor.yellow : HighlightColor.blue,
            );
          }
        });
        await pumpGoldenSurface(
          tester,
          profile,
          (_) => ReaderScreen(
            sourceId: comic.id,
            bookRepository: app.bookRepository,
            highlightRepository: app.highlightRepository,
            preferencesService: app.preferencesService,
            screenControlService: app.screenControlService,
            textActions: const [],
            initialSource: comic,
          ),
          surfaceSize: profile == VisualProfile.tabletRtl
              ? const Size(390, 844)
              : null,
        );
        await waitForUi(
          tester,
          () => find.byType(FixedPagesView).evaluate().isNotEmpty,
          description: 'comic pages',
          timeout: const Duration(seconds: 30),
        );
        final context = tester.element(find.byType(FixedPagesView));
        final bloc = context.read<ReaderBloc>();
        await waitForUi(
          tester,
          () => bloc.state.highlights.length == 100,
          description: 'saved areas',
        );
        await waitForFixedPage(tester);
        final ui = context.read<ReaderUiCubit>();
        final l10n = context.l10n;
        ui.openTocDrawer();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l10n.readerHighlights));
        await tapUi(tester, find.text(l10n.readerHighlights));
        await decodeVisiblePreviews(tester);
        await tester.pumpAndSettle();
        final previews = find.byType(ReaderImageHighlightPreview);
        final mounted = previews
            .evaluate()
            .map(
              (e) => (e.widget as ReaderImageHighlightPreview).area.pageIndex,
            )
            .toSet();
        expect(mounted, isNotEmpty);
        final thumbnails = tester
            .element(previews.first)
            .read<ReaderPageThumbnailCubit>();
        expect(
          thumbnails.state.keys.toSet(),
          mounted,
          reason: 'only mounted rows load their pages',
        );
        expect(
          find.byType(ReaderHighlightListTile).evaluate().length,
          lessThan(10),
        );
        expect(find.text('Page highlight'), findsNothing);
        expect(find.byTooltip(l10n.commonCopy), findsNothing);
        await expectUiGolden(tester, profile, 'comic-highlights');
        await tapUi(tester, find.text(l10n.readerBookmarks));
        expect(thumbnails.isClosed, isTrue);

        if (profile == VisualProfile.phone) {
          await tapUi(tester, find.text(l10n.readerHighlights));
          await tester.ensureVisible(find.text(l10n.readerExpandHighlight));
          await tapUi(tester, find.text(l10n.readerExpandHighlight));
          expect(tester.widget<Text>(find.text(note)).maxLines, isNull);
          expect(ui.state.tocDrawerVisible, isTrue);
          await tester.ensureVisible(find.text(l10n.readerCollapseHighlight));
          await tapUi(tester, find.text(l10n.readerCollapseHighlight));
          await tapUi(tester, find.byTooltip(l10n.highlightColorYellow));
          expect(find.byType(ReaderHighlightListTile), findsNWidgets(2));
          await tapUi(tester, find.text(l10n.readerBookmarks));
          await tapUi(tester, find.text(l10n.readerHighlights));
          expect(
            find.byType(ReaderHighlightListTile),
            findsNWidgets(2),
            reason: 'Changing tabs preserves the color filter',
          );
          await tapUi(tester, find.text('A quiet afternoon.'));
          expect(ui.state.tocDrawerVisible, isFalse);
          await waitForUi(
            tester,
            () => bloc.state.document?.currentCfi == 'epubcfi(/6/10)',
            description: 'the area\'s page',
          );
          await tester.pump(const Duration(milliseconds: 350));
        }
        // The reader saves its place after a pause.
        await tester.pump(const Duration(seconds: 1));
        await unmountUi(tester);
      },
      tags: ['golden'],
    );
  }
}
