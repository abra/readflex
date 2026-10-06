import 'package:domain_models/domain_models.dart';
import 'package:highlight_repository/highlight_repository.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  /// Awaited before any re-add completes, so tests can observe busy rows.
  Future<void>? addGate;

  final Map<String, List<Highlight>> highlightsBySourceId = {};
  final List<Highlight> imageAreaHighlights = [];
  final List<Highlight> addedHighlights = [];
  final List<String> deletedHighlightIds = [];
  final List<Highlight> updatedHighlights = [];

  void seedHighlights(String sourceId, List<Highlight> highlights) {
    highlightsBySourceId[sourceId] = highlights;
  }

  @override
  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    if (shouldThrow) throw Exception('getHighlightsBySource failed');
    return List.of(highlightsBySourceId[sourceId] ?? []);
  }

  @override
  Future<Highlight> addHighlight({
    required String sourceId,
    required SourceType sourceType,
    required String text,
    String? note,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
    double? progress,
    String? chapterTitle,
    HighlightColor color = HighlightColor.yellow,
    List<String> replaceHighlightIds = const [],
  }) async {
    await addGate;
    if (shouldThrow) throw Exception('addHighlight failed');
    final highlight = Highlight(
      id: 'highlight-${addedHighlights.length + 1}',
      sourceId: sourceId,
      sourceType: sourceType,
      text: text,
      note: note,
      cfiRange: cfiRange,
      pageNumber: pageNumber,
      scrollOffset: scrollOffset,
      progress: progress,
      chapterTitle: chapterTitle,
      color: color,
      createdAt: DateTime(2030),
    );
    addedHighlights.add(highlight);
    highlightsBySourceId.putIfAbsent(sourceId, () => []).add(highlight);
    return highlight;
  }

  @override
  Future<Highlight> addImageAreaHighlight({
    required String sourceId,
    required SourceType sourceType,
    required int pageIndex,
    required double x,
    required double y,
    required double width,
    required double height,
    String? note,
    double? progress,
    String? chapterTitle,
    HighlightColor color = HighlightColor.yellow,
  }) async {
    await addGate;
    if (shouldThrow) throw Exception('addImageAreaHighlight failed');
    final highlight = Highlight(
      id: 'image-highlight-${imageAreaHighlights.length + 1}',
      sourceId: sourceId,
      sourceType: sourceType,
      text: 'Page highlight',
      note: note,
      kind: HighlightKind.imageArea,
      imageArea: HighlightImageArea(
        pageIndex: pageIndex,
        x: x,
        y: y,
        width: width,
        height: height,
      ),
      pageNumber: pageIndex + 1,
      progress: progress,
      chapterTitle: chapterTitle,
      color: color,
      createdAt: DateTime(2030),
    );
    imageAreaHighlights.add(highlight);
    highlightsBySourceId.putIfAbsent(sourceId, () => []).add(highlight);
    return highlight;
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
  Future<void> updateHighlightColor(String id, HighlightColor color) async {
    final highlight = highlightsBySourceId.values
        .expand((items) => items)
        .firstWhere((highlight) => highlight.id == id);
    await updateHighlight(highlight.copyWith(color: color));
  }

  @override
  Future<void> updateHighlightNote(String id, String? note) async {
    final highlight = highlightsBySourceId.values
        .expand((items) => items)
        .firstWhere((highlight) => highlight.id == id);
    await updateHighlight(highlight.copyWith(note: note));
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
