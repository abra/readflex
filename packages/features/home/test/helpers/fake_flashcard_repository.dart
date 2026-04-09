import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

class FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<ReviewItem> dueItems = [];
  bool shouldThrow = false;

  @override
  Future<List<ReviewItem>> getDueItems({ReviewableType? type}) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueItems);
  }
}
