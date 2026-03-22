import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

class FakeHighlightRepository extends HighlightRepository {
  bool shouldThrow = false;

  final List<Highlight> highlights = [];

  @override
  Future<Highlight> addHighlight({
    required String sourceId,
    required SourceType sourceType,
    required String text,
    String? note,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
    HighlightColor color = HighlightColor.yellow,
  }) async {
    if (shouldThrow) throw Exception('addHighlight failed');

    final highlight = Highlight(
      id: 'h-${highlights.length + 1}',
      sourceId: sourceId,
      sourceType: sourceType,
      text: text,
      note: note,
      cfiRange: cfiRange,
      pageNumber: pageNumber,
      scrollOffset: scrollOffset,
      color: color,
      createdAt: DateTime.now(),
    );
    highlights.add(highlight);
    return highlight;
  }
}
