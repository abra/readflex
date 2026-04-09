/// FSRS review rating.
enum Rating {
  again,
  hard,
  good,
  easy
  ;

  /// Parses a [Rating] from its stored [name]. Falls back to [again] on
  /// unknown values.
  static Rating from(String value) => values.asNameMap()[value] ?? again;
}
