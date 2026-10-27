/// Vellum: the native reader engine, the Flutter analogue of foliate-js.
///
/// Modules mirror foliate-js one to one (see README): containers and
/// formats open a file and hand out sections and bytes; the document model,
/// layout and paginator draw them; `ReaderView` is the one widget the app
/// embeds. Nothing here knows about the app's domain models or storage.
library;

export 'src/container/zip_archive.dart';
export 'src/container/zip_entry.dart';
export 'src/vellum_exception.dart';
export 'src/formats/comic_page_order.dart'
    show
        NaturalSortKey,
        currentComicPageOrderVersion,
        naturalFilenameCompare,
        selectComicPages;
export 'src/formats/comic_book.dart';
export 'src/formats/comic_page.dart';
export 'src/formats/pdf_book.dart';
export 'src/formats/pdf_text_layer.dart';
export 'src/formats/pdf_text_layer_cache.dart';
export 'src/search/pdf_book_search.dart';
export 'src/search/text_search.dart';
export 'src/pdf/pdf_engine.dart';
export 'src/image/image_dimensions.dart';
export 'src/image/page_content.dart';
export 'src/epubcfi/fake_cfi.dart';
export 'src/epubcfi/pdf_anchor.dart';
export 'src/metadata/book_metadata.dart';
export 'src/metadata/comic_metadata.dart';
export 'src/metadata/cover_thumbnail.dart';
export 'src/metadata/pdf_metadata.dart';
export 'src/fixed_layout/comic_page_image.dart';
export 'src/fixed_layout/spread_layout.dart';
export 'src/formats/comic_page_source.dart';
export 'src/fixed_layout/fixed_pages_controller.dart';
export 'src/fixed_layout/fixed_page_source.dart';
export 'src/fixed_layout/fixed_pages_view.dart';
export 'src/fixed_layout/comic_image_area.dart';
export 'src/fixed_layout/comic_image_area_layer.dart';
export 'src/fixed_layout/comic_page_thumbnail.dart';
export 'src/fixed_layout/page_colors.dart';
export 'src/fixed_layout/pdf_page_content.dart';
export 'src/fixed_layout/pdf_page_image.dart';
export 'src/fixed_layout/pdf_pages.dart';
export 'src/fixed_layout/pdf_text_overlay.dart';
export 'src/fixed_layout/pdf_text_selection.dart';
export 'src/fixed_layout/zoom_tiles.dart';
export 'src/fixed_layout/pdf_page_thumbnail.dart';
