/// Color options for text highlights.
enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  purple
  ;

  static HighlightColor from(String value) => switch (value) {
    'yellow' => yellow,
    'green' => green,
    'blue' => blue,
    'pink' => pink,
    'purple' => purple,
    _ => yellow,
  };
}
