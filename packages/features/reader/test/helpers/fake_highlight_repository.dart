import 'package:domain_models/domain_models.dart';
import 'package:highlight_repository/highlight_repository.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final Map<String, List<Highlight>> highlightsBySourceId = {};
  final List<String> deletedHighlightIds = [];
  final List<Highlight> updatedHighlights = [];

  void seedHighlights(String sourceId, List<Highlight> highlights) {
    highlightsBySourceId[sourceId] = highlights;
  }

  @override
  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    if (shouldThrow) throw Exception('getHighlightsBySource failed');
    return highlightsBySourceId[sourceId] ?? [];
  }

  @override
  Future<void> deleteHighlight(String id) async {
    if (shouldThrow) throw Exception('deleteHighlight failed');
    deletedHighlightIds.add(id);
    for (final entry in highlightsBySourceId.entries) {
      entry.value.removeWhere((highlight) => highlight.id == id);
    }
  }

  @override
  Future<Highlight> updateHighlight(Highlight highlight) async {
    if (shouldThrow) throw Exception('updateHighlight failed');
    updatedHighlights.add(highlight);
    final highlights = highlightsBySourceId[highlight.sourceId];
    if (highlights == null) return highlight;
    final index = highlights.indexWhere(
      (existing) => existing.id == highlight.id,
    );
    if (index == -1) return highlight;
    highlights[index] = highlight;
    return highlight;
  }
}
