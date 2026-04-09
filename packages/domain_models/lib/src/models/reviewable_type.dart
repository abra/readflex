/// The type of item being reviewed with FSRS.
enum ReviewableType {
  flashcard,
  highlight,
  dictionary
  ;

  /// Parses a [ReviewableType] from its stored [name]. Falls back to
  /// [flashcard] on unknown values.
  static ReviewableType from(String value) =>
      values.asNameMap()[value] ?? flashcard;

  String toStorageString() => name;
}
