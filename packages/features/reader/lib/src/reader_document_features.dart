/// Document-level capabilities the page surface reports once it reads the
/// document.
///
/// Some formats expose optional structures such as a table of contents.
/// Null means "not detected yet".
class ReaderDocumentFeatures {
  const ReaderDocumentFeatures({
    required this.format,
    this.hasTableOfContents,
    this.hasSearchableText,
    this.pageCount,
  });

  final String? format;
  final bool? hasTableOfContents;

  /// Unknown (null) until the document shows text or proves it has some;
  /// PDF and DjVu report `true` once a loaded page contains selectable text.
  final bool? hasSearchableText;

  /// Number of fixed pages (PDF/DjVu), for the Pages grid. Null for reflowable
  /// formats, whose page count depends on layout.
  final int? pageCount;

  // Surfaces report features more than once; equal values must not rebuild
  // the chrome that selects them.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderDocumentFeatures &&
          format == other.format &&
          hasTableOfContents == other.hasTableOfContents &&
          hasSearchableText == other.hasSearchableText &&
          pageCount == other.pageCount;

  @override
  int get hashCode =>
      Object.hash(format, hasTableOfContents, hasSearchableText, pageCount);
}
