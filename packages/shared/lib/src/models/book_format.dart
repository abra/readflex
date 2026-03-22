/// Supported book file formats.
enum BookFormat {
  epub,
  fb2,
  mobi,
  pdf;

  /// Parses a [BookFormat] from a stored string value.
  static BookFormat from(String? value) => switch (value) {
    'epub' => BookFormat.epub,
    'fb2' => BookFormat.fb2,
    'mobi' => BookFormat.mobi,
    'pdf' => BookFormat.pdf,
    _ => BookFormat.epub,
  };

  /// Parses a [BookFormat] from a file extension (e.g. '.epub').
  static BookFormat? fromExtension(String extension) =>
      switch (extension.toLowerCase()) {
        '.epub' => BookFormat.epub,
        '.fb2' => BookFormat.fb2,
        '.mobi' => BookFormat.mobi,
        '.pdf' => BookFormat.pdf,
        _ => null,
      };
}
