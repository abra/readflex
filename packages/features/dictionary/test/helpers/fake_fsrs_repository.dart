import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

class FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Set<String> masteredIds = {};
  bool shouldThrow = false;

  @override
  Future<Set<String>> getMasteredItemIds({ReviewableType? type}) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return masteredIds;
  }

  @override
  Future<void> deleteReviewItem(String itemId) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    masteredIds.remove(itemId);
  }
}
