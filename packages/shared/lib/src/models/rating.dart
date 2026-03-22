/// FSRS review rating.
enum Rating {
  again,
  hard,
  good,
  easy
  ;

  static Rating from(String value) => switch (value) {
    'again' => again,
    'hard' => hard,
    'good' => good,
    'easy' => easy,
    _ => again,
  };
}
