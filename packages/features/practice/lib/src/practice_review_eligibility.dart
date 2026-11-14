import 'package:domain_models/domain_models.dart';

/// Active review types, shared by hub counts, source summaries and sessions.
class PracticeReviewEligibility {
  const PracticeReviewEligibility({required this.reviewHighlights});

  static const _words = {ReviewableType.dictionary};
  static const _wordsAndHighlights = {
    ReviewableType.dictionary,
    ReviewableType.highlight,
  };

  final bool reviewHighlights;

  Set<ReviewableType> get types =>
      reviewHighlights ? _wordsAndHighlights : _words;

  bool includes(ReviewableType type) => types.contains(type);

  int dueCount(ReviewStats stats) =>
      types.fold(0, (count, type) => count + stats.dueOf(type));
}
