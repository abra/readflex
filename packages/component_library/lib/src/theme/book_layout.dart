/// User-selectable layout density presets for the book reader.
///
/// Controls margins, line spacing, font size, paragraph spacing, and
/// hyphenation. Independent from theme colors ([ReaderThemeData]) and
/// font family ([ReaderFontPreset]).
enum BookLayoutPreset {
  compact,
  standard,
  comfortable,
  ;

  static BookLayoutPreset fromId(String? value) => switch (value) {
    'compact' => compact,
    'comfortable' => comfortable,
    _ => standard,
  };

  String get id => name;

  String get label => switch (this) {
    compact => 'Compact',
    standard => 'Standard',
    comfortable => 'Comfortable',
  };
}

/// Layout + typography scale values for the book reader.
///
/// Values are in the units foliate-js expects:
/// - [fontSize] in `em`
/// - [lineHeight] as multiplier
/// - [topMargin] / [bottomMargin] in `px`
/// - [sideMargin] in percent of viewport width
/// - [textIndent] in `em`
/// - [letterSpacing] in `px`
class BookLayoutData {
  const BookLayoutData({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.textIndent,
    required this.topMargin,
    required this.bottomMargin,
    required this.sideMargin,
    required this.letterSpacing,
    required this.fontWeight,
    required this.justify,
    required this.hyphenate,
  });

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double textIndent;
  final double topMargin;
  final double bottomMargin;
  final double sideMargin;
  final double letterSpacing;
  final double fontWeight;
  final bool justify;
  final bool hyphenate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookLayoutData &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          paragraphSpacing == other.paragraphSpacing &&
          textIndent == other.textIndent &&
          topMargin == other.topMargin &&
          bottomMargin == other.bottomMargin &&
          sideMargin == other.sideMargin &&
          letterSpacing == other.letterSpacing &&
          fontWeight == other.fontWeight &&
          justify == other.justify &&
          hyphenate == other.hyphenate;

  @override
  int get hashCode => Object.hash(
    fontSize,
    lineHeight,
    paragraphSpacing,
    textIndent,
    topMargin,
    bottomMargin,
    sideMargin,
    letterSpacing,
    fontWeight,
    justify,
    hyphenate,
  );
}

extension BookLayoutPresetX on BookLayoutPreset {
  BookLayoutData get data => switch (this) {
    BookLayoutPreset.compact => const BookLayoutData(
      fontSize: 1.0,
      lineHeight: 1.4,
      paragraphSpacing: 0.3,
      textIndent: 1.2,
      topMargin: 50,
      bottomMargin: 25,
      sideMargin: 5,
      letterSpacing: 0,
      fontWeight: 400,
      justify: false,
      hyphenate: false,
    ),
    BookLayoutPreset.standard => const BookLayoutData(
      fontSize: 1.0,
      lineHeight: 1.6,
      paragraphSpacing: 0.5,
      textIndent: 1.5,
      topMargin: 65,
      bottomMargin: 35,
      sideMargin: 6,
      letterSpacing: 0,
      fontWeight: 400,
      justify: false,
      hyphenate: false,
    ),
    BookLayoutPreset.comfortable => const BookLayoutData(
      fontSize: 1.3,
      lineHeight: 1.8,
      paragraphSpacing: 0.7,
      textIndent: 1.5,
      topMargin: 75,
      bottomMargin: 40,
      sideMargin: 8,
      letterSpacing: 0.3,
      fontWeight: 400,
      justify: false,
      hyphenate: true,
    ),
  };
}
