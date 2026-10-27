/// The choices Practice settings offer, and how a stored value maps onto
/// them: a preference written elsewhere (a future import, an old build)
/// shows as its nearest choice and is only rewritten when the reader picks
/// one.
library;

/// How sure of a card the reader wants to be when it comes back: FSRS's
/// desired retention as three presets, Anki's advice for people who do not
/// tune parameters.
enum PracticeMemoryTarget {
  /// Fewer reviews; a card may be forgotten one time in five.
  lighter(0.8),

  /// The default: a card comes back while nine in ten would still be known.
  balanced(0.9),

  /// More reviews; a card comes back while nineteen in twenty are known.
  stronger(0.95);

  const PracticeMemoryTarget(this.desiredRetention);

  final double desiredRetention;

  /// The preset whose retention is closest to [desiredRetention].
  static PracticeMemoryTarget nearest(double desiredRetention) => values.reduce(
    (a, b) =>
        (a.desiredRetention - desiredRetention).abs() <=
            (b.desiredRetention - desiredRetention).abs()
        ? a
        : b,
  );
}

/// Never-reviewed cards a day's sessions may introduce.
const List<int> practiceNewCardsPresets = [10, 20, 40];

/// The preset closest to [newCardsPerDay].
int nearestNewCardsPreset(int newCardsPerDay) => practiceNewCardsPresets.reduce(
  (a, b) => (a - newCardsPerDay).abs() <= (b - newCardsPerDay).abs() ? a : b,
);
