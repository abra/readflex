/// Color options for text highlights.
enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  purple;

  static HighlightColor from(String value) => HighlightColor.values.firstWhere(
    (e) => e.name == value,
    orElse: () => HighlightColor.yellow,
  );
}
