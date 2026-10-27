import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_surface.dart';
import 'package:reader/src/reader_webview_surface.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  // `GlobalKey.currentState` reads the widgets binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Before the WebView mounts the key has no state: every command the
  // screen may send early must be dropped, and every query must answer
  // null, as the key-based calls did.
  test(
    'an unmounted WebView surface drops commands and answers null',
    () async {
      final ReaderSurface surface = ReaderWebViewSurface(
        GlobalKey<BookReaderWebViewState>(),
      );
      surface
        ..goToCfi('epubcfi(/6/2)')
        ..goToFraction(0.5)
        ..goToHref('ch1.xhtml')
        ..goToSectionIndex(3)
        ..goToSearchResult('epubcfi(/6/4)')
        ..goToBookmark(cfi: 'epubcfi(/6/2)', progress: 0.1)
        ..pageLeft()
        ..pageRight()
        ..prevPage()
        ..nextPage()
        ..toggleBookmark()
        ..clearSearch()
        ..clearSelection()
        ..clearSelectionAfterTextAction()
        ..showSelectionHighlightPreview(cfiRange: 'x', color: '#fff')
        ..clearSelectionHighlightPreview()
        ..showImageAreaSelectionPreview(
          pageIndex: 0,
          rect: const ReaderImageAreaRect(x: 0, y: 0, width: 1, height: 1),
          color: '#fff',
        )
        ..clearImageAreaSelectionPreview(allowNextTap: true)
        ..setImageAreaSelectionPreviewRetained(true)
        ..setImageAreaSelectionControlsBounds(
          const ReaderSelectionPosition(left: 0, top: 0, right: 1, bottom: 1),
        )
        ..clearImageAreaSelectionControlsBounds();

      expect(surface.searchBookStream('sea'), isNull);
      expect(await surface.currentTextSelection(), isNull);
      expect(await surface.pageThumbnail(0), isNull);
    },
  );

  test('WebView previews become MemoryImages, oversized ones nothing', () {
    expect(readerThumbnailImageFor(null), isNull);
    final small = Uint8List(ReaderWebViewSurface.maxThumbnailBytes);
    final image = readerThumbnailImageFor(small);
    expect(image, isA<MemoryImage>());
    expect(
      image,
      readerThumbnailImageFor(small),
      reason: 'same bytes, same key',
    );
    expect(
      readerThumbnailImageFor(
        Uint8List(ReaderWebViewSurface.maxThumbnailBytes + 1),
      ),
      isNull,
    );
  });
}
