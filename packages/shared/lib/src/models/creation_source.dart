/// How a flashcard was created.
enum CreationSource {
  manual,
  aiHighlight,
  aiSelection
  ;

  static CreationSource from(String value) => switch (value) {
    'manual' => manual,
    'aiHighlight' => aiHighlight,
    'aiSelection' => aiSelection,
    _ => manual,
  };
}
