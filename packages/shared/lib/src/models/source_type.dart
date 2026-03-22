/// The type of reading source.
enum SourceType {
  book,
  article;

  /// Parses a [SourceType] from a stored string value.
  static SourceType from(String? value) => switch (value) {
    'book' => SourceType.book,
    'article' => SourceType.article,
    _ => SourceType.book,
  };
}
