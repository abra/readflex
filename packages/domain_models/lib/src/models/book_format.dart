/// Supported book file formats.
enum BookFormat {
  epub,
  fb2,
  mobi,
  pdf,
  azw3,
  cbz,
  djvu
  ;

  /// Parses a [BookFormat] from its stored [name]. Falls back to [epub] on
  /// unknown or null values.
  static BookFormat from(String? value) =>
      value == null ? epub : values.asNameMap()[value] ?? epub;

  /// Parses a [BookFormat] from a file extension (e.g. '.epub').
  static BookFormat? fromExtension(String extension) {
    final key = extension.toLowerCase().replaceFirst('.', '');
    if (key == 'djv') return djvu;
    return values.asNameMap()[key];
  }
}
