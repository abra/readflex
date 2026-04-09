/// The type of reading source.
enum SourceType {
  book,
  article
  ;

  /// Parses a [SourceType] from its stored [name]. Falls back to [book] on
  /// unknown or null values.
  static SourceType from(String? value) =>
      value == null ? book : values.asNameMap()[value] ?? book;
}
