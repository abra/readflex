/// Joins the notes of highlights merged into one, in the given order.
///
/// Blank notes are dropped and an exact repeat (after trimming) is kept once,
/// so re-saving a highlight with the note it already has does not double it.
/// Returns `null` when nothing remains.
String? mergeHighlightNotes(Iterable<String?> notes) {
  final kept = <String>[];
  for (final note in notes) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty || kept.contains(trimmed)) continue;
    kept.add(trimmed);
  }
  return kept.isEmpty ? null : kept.join('\n\n');
}
