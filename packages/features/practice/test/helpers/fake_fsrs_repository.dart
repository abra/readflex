import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

class FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<ReviewItem> dueItems = [];
  Map<String, List<ReviewItem>> dueItemsBySource = {};
  bool shouldThrow = false;
  final List<({String itemId, ReviewableType itemType, Rating rating})>
  reviews = [];

  @override
  Future<List<ReviewItem>> getDueItemsBySource(
    String sourceId, {
    ReviewableType? type,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueItemsBySource[sourceId] ?? []);
  }

  @override
  Future<List<ReviewItem>> getDueItems({ReviewableType? type}) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueItems);
  }

  @override
  Future<FsrsCardData> recordReview({
    required String itemId,
    required ReviewableType itemType,
    required Rating rating,
    int? reviewDurationMs,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    reviews.add((itemId: itemId, itemType: itemType, rating: rating));
    return const FsrsCardData();
  }
}
