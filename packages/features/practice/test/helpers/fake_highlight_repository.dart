import 'package:domain_models/domain_models.dart';
import 'package:highlight_repository/highlight_repository.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final Map<String, Highlight> _highlights = {};
  bool shouldThrow = false;

  void seed(List<Highlight> highlights) {
    _highlights.clear();
    for (final h in highlights) {
      _highlights[h.id] = h;
    }
  }

  @override
  Future<Highlight?> getHighlightById(String id) async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return _highlights[id];
  }
}
