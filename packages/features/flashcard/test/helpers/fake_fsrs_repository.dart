import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

class FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<({String itemId, ReviewableType itemType, String? sourceId})>
  created = [];
  bool shouldThrow = false;

  @override
  Future<void> createReviewItem({
    required String itemId,
    required ReviewableType itemType,
    String? sourceId,
  }) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    created.add((itemId: itemId, itemType: itemType, sourceId: sourceId));
  }
}
