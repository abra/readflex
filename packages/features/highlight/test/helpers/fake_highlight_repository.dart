import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:highlight_repository/highlight_repository.dart';

class FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  /// When set, `addHighlight` blocks on this completer's future before
  /// resolving. Tests use this to simulate "user dismissed sheet
  /// mid-save" by closing the cubit while the call is in flight.
  Completer<void>? awaitGate;

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
    if (awaitGate != null) await awaitGate!.future;
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
