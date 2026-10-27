import 'package:flutter/painting.dart';

import '../formats/comic_page_source.dart';
import 'comic_page_image.dart';

/// What `FixedPagesView` draws: pages that are images of a known count,
/// each an [ImageProvider] at the width the view asks for.
///
/// A comic decodes its stored images; a PDF renders its pages. Two sources
/// are the same page set when they are the same object, which is what the
/// providers' cache keys compare.
abstract interface class FixedPageSource {
  int get pageCount;

  /// The displayed width-to-height ratio of a page, known before it is
  /// drawn (a PDF page's size), or null when only decoding tells (a comic
  /// page's image). Spreads lay out with the ratio and refit without it.
  double? pageAspect(int index);

  /// Page [index] decoded or rendered [targetWidth] pixels wide; narrower
  /// comic pages keep their own size.
  ImageProvider pageImage(int index, {required int targetWidth});

  /// Page [index] at preview size, for lists of bookmarks and highlights.
  ImageProvider pageThumbnail(int index);

  /// [region] of page [index] rendered as if the whole page were
  /// [fullWidth] pixels wide, for a sharp view of a zoomed page; null when
  /// the source has no sharper rendering than [pageImage] (a comic's scan
  /// is already its sharpest).
  ImageProvider? pageTile(
    int index, {
    required int fullWidth,
    required ({int x, int y, int width, int height}) region,
  });
}

/// A comic's pages as [FixedPageSource]: decoded by `ComicPageImage` from
/// the bytes of a `ComicPageSource`.
class ComicPages implements FixedPageSource {
  const ComicPages(this.source);

  final ComicPageSource source;

  @override
  int get pageCount => source.pageCount;

  @override
  double? pageAspect(int index) => null;

  @override
  ImageProvider pageImage(int index, {required int targetWidth}) =>
      ComicPageImage(
        source: source,
        pageIndex: index,
        targetWidth: targetWidth,
      );

  @override
  ImageProvider pageThumbnail(int index) => ComicPageImage(
    source: source,
    pageIndex: index,
    targetWidth: ComicPageImage.thumbnailWidth,
    maxBytes: ComicPageImage.thumbnailMaxBytes,
  );

  @override
  ImageProvider? pageTile(
    int index, {
    required int fullWidth,
    required ({int x, int y, int width, int height}) region,
  }) => null;

  @override
  bool operator ==(Object other) =>
      other is ComicPages && identical(other.source, source);

  @override
  int get hashCode => identityHashCode(source);
}
