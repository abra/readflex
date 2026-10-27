import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

/// Review counts the Library reads for its Practice entry.
class FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  ReviewStats stats = const ReviewStats();
  bool shouldThrow = false;
  int getStatsCallCount = 0;

  @override
  Future<ReviewStats> getStats() async {
    getStatsCallCount++;
    if (shouldThrow) throw StorageException(cause: 'fake error');
    return stats;
  }
}

ReviewStats reviewStats({
  int words = 0,
  int highlights = 0,
  int due = 0,
  int dueHighlights = 0,
}) => ReviewStats(
  totalByType: {
    ReviewableType.dictionary: words,
    ReviewableType.highlight: highlights,
  },
  // [due] words; highlights only count while the setting reviews them.
  dueByType: {
    ReviewableType.dictionary: due,
    ReviewableType.highlight: dueHighlights,
  },
);
