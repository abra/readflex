import 'package:domain_models/domain_models.dart';
import 'package:highlight_repository/highlight_repository.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Highlight> highlights = [];
  bool shouldThrow = false;
  bool getHighlightsCalled = false;
  bool getHighlightCountCalled = false;
  bool throwOnFullListLoad = false;

  @override
  Future<List<Highlight>> getHighlights() async {
    getHighlightsCalled = true;
    if (throwOnFullListLoad) throw StorageException(cause: 'full list load');
    if (shouldThrow) throw StorageException(cause: 'fake');
    return highlights;
  }

  @override
  Future<int> getHighlightCount() async {
    getHighlightCountCalled = true;
    if (shouldThrow) throw StorageException(cause: 'fake');
    return highlights.length;
  }
}
