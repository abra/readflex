/// How a flashcard was created.
enum CreationSource {
  manual,
  aiHighlight,
  aiSelection
  ;

  static CreationSource from(String value) => CreationSource.values.firstWhere(
    (e) => e.name == value,
    orElse: () => CreationSource.manual,
  );
}
