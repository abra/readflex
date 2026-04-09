/// Color options for text highlights.
enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  purple
  ;

  /// Parses a [HighlightColor] from its stored [name]. Falls back to [yellow]
  /// on unknown values.
  static HighlightColor from(String value) =>
      values.asNameMap()[value] ?? yellow;
}
