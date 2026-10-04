import 'dart:convert';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_comic_thumbnail_cubit.dart';
import 'package:reader/src/reader_highlight_list_tile.dart';
import 'package:reader/src/reader_image_highlight_preview.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/comic_fixture.dart';
import '../support/reader_test_platform.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  Future<void> decodeVisiblePreviews(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final previews = find.byType(ReaderImageHighlightPreview);
    final context = tester.element(previews.first);
    final cache = context.read<ReaderComicThumbnailCubit>().state;
    // The bridge decodes base64 into new byte identities. Precache those actual
    // ImageCache keys, not the fixture bytes, before capturing painted crops.
    await tester.runAsync(() async {
      for (final bytes in cache.values) {
        if (bytes != null) await precacheImage(MemoryImage(bytes), context);
      }
    });
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: previews, matching: find.byIcon(AppIcons.book)),
      findsNothing,
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
        final bytes = (await tester.runAsync(
          () => comicPageFixture(2, size: const Size(240, 360)),
        ))!;
        final previous = InAppWebViewPlatform.instance;
        final requests = <int>[];
        var failPreview = false;
        final platform = ReaderTestPlatform(
          onAsyncJavaScript: (body, args) async {
            expect(body, contains('readflexComicThumbnail'));
            requests.add(args['index'] as int);
            return CallAsyncJavaScriptResult(
              value: failPreview
                  ? null
                  : 'data:image/jpeg;base64,${base64Encode(bytes)}',
            );
          },
        );
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          if (previous != null) InAppWebViewPlatform.instance = previous;
        });
        final note = List.filled(
          8,
          'The two panels tell the story from different perspectives.',
        ).join(' ');
        await tester.runAsync(() async {
          // More entries than fit in any viewport. Shared pages must not start
          // duplicate bridge work, nor should offscreen rows request thumbnails.
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
            serverBaseUri: Uri.parse('http://127.0.0.1:49152'),
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
          () => platform.views.any(
            (v) => v.created && v.controller.handlers.containsKey('onLoadEnd'),
          ),
          description: 'reader bridge',
        );
        final bridge = platform.views.firstWhere((v) => v.created).controller;
        bridge.handlers['onLoadEnd']!([]);
        final context = tester.element(find.byType(BookReaderWebView));
        final bloc = context.read<ReaderBloc>();
        await waitForUi(
          tester,
          () => bloc.state.highlights.length == 100,
          description: 'saved areas',
        );
        final ui = context.read<ReaderUiCubit>();
        final l10n = context.l10n;
        // No TOC is sent: isolate Highlights from the separately tested Pages grid.
        ui.openTocDrawer();
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
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
        expect(requests.toSet(), mounted);
        expect(requests.length, mounted.length);
        expect(
          find.byType(ReaderHighlightListTile).evaluate().length,
          lessThan(10),
        );
        expect(find.text('Page highlight'), findsNothing);
        expect(find.byTooltip(l10n.commonCopy), findsNothing);
        await expectUiGolden(tester, profile, 'comic-highlights');
        final thumbnails = tester
            .element(previews.first)
            .read<ReaderComicThumbnailCubit>();
        await tapUi(tester, find.text(l10n.readerBookmarks));
        expect(thumbnails.isClosed, isTrue);
        final count = requests.length;
        await tester.pump(const Duration(seconds: 1));
        expect(requests.length, count);

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
          expect(
            bridge.scripts.any((s) => s.contains('goToSectionIndex(4)')),
            isTrue,
          );
          final beforeOpen = requests.length;
          await tester.pumpAndSettle();
          expect(requests.length, beforeOpen);

          failPreview = true;
          ui.openTocDrawer();
          await tester.pumpAndSettle();
          // Tab selection may be restored or reset by the host; choose it explicitly.
          await tapUi(tester, find.text(l10n.readerHighlights));
          await tester.pumpAndSettle();
          expect(find.byTooltip(l10n.commonRetry), findsWidgets);
          await expectUiGolden(
            tester,
            profile,
            'comic-highlights-preview-error',
          );
          failPreview = false;
          await tapUi(tester, find.byTooltip(l10n.commonRetry).first);
          await decodeVisiblePreviews(tester);
          await tester.pumpAndSettle();
          expect(find.byTooltip(l10n.commonRetry), findsNothing);
          expect(ui.state.tocDrawerVisible, isTrue);
        }
        await unmountUi(tester);
      },
      tags: ['golden'],
    );
  }
}
