import 'package:highlight_repository/highlight_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final Map<String, List<Highlight>> highlightsBySourceId = {};

  void seedHighlights(String sourceId, List<Highlight> highlights) {
    highlightsBySourceId[sourceId] = highlights;
  }

  @override
  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    if (shouldThrow) throw Exception('getHighlightsBySource failed');
    return highlightsBySourceId[sourceId] ?? [];
  }
}
