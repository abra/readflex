/// The type of item being reviewed with FSRS.
enum ReviewableType {
  flashcard,
  highlight,
  dictionary
  ;

  static ReviewableType from(String value) => switch (value) {
    'highlight' => ReviewableType.highlight,
    'dictionary' => ReviewableType.dictionary,
    _ => ReviewableType.flashcard,
  };

  String toStorageString() => name;
}
