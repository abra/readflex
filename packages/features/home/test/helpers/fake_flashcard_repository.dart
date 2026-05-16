import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

class FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<ReviewItem> dueItems = [];
  bool shouldThrow = false;
  bool getDueItemsCalled = false;
  bool getDueItemCountCalled = false;
  bool throwOnFullListLoad = false;

  @override
  Future<List<ReviewItem>> getDueItems({
    ReviewableType? type,
    int? limit,
    int? offset,
  }) async {
    getDueItemsCalled = true;
    if (throwOnFullListLoad) throw StorageException(cause: 'full list load');
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueItems);
  }

  @override
  Future<int> getDueItemCount({ReviewableType? type}) async {
    getDueItemCountCalled = true;
    if (shouldThrow) throw StorageException(cause: 'fake');
    if (type == null) return dueItems.length;
    return dueItems.where((item) => item.itemType == type).length;
  }
}
