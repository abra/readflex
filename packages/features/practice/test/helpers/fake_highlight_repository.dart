import 'package:domain_models/domain_models.dart';
import 'package:highlight_repository/highlight_repository.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Highlight> dueHighlights = [];
  bool shouldThrow = false;

  @override
  Future<List<Highlight>> getDueHighlights() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(dueHighlights);
  }
}
