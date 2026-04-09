/// How a flashcard was created.
enum CreationSource {
  manual,
  aiHighlight,
  aiSelection
  ;

  /// Parses a [CreationSource] from its stored [name]. Falls back to [manual]
  /// on unknown values.
  static CreationSource from(String value) =>
      values.asNameMap()[value] ?? manual;
}
