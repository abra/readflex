/// FSRS review rating.
enum Rating {
  again,
  hard,
  good,
  easy
  ;

  static Rating from(String value) => Rating.values.firstWhere(
    (e) => e.name == value,
    orElse: () => Rating.again,
  );
}
