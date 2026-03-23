import 'package:highlight_repository/highlight_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<Highlight> highlights = [];
  bool shouldThrow = false;

  @override
  Future<List<Highlight>> getHighlights() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return List.unmodifiable(highlights);
  }
}
