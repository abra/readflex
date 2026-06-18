import 'package:equatable/equatable.dart' show Equatable;

import 'source_type.dart';

/// How a saved dictionary entry was anchored back to source text.
enum DictionaryAnchorKind {
  /// Exact range selected by the user.
  exactSelection,

  /// Reader expanded the selection to full word boundaries.
  normalizedSelection,

  /// Saved entry represents a larger expression than the tapped token.
  expression,

  /// Saved range is a larger text selection rather than a lexical item.
  longSelection
  ;

  static DictionaryAnchorKind from(String value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return DictionaryAnchorKind.exactSelection;
  }
}

/// Exact source location where a dictionary entry was saved from.
///
/// The dictionary entry is the learning item; this anchor is only the
/// source-specific bridge needed to underline the saved text in a book/article
/// and open the already-saved entry when the user taps that underline.
class DictionaryAnchor extends Equatable {
  const DictionaryAnchor({
    required this.id,
    required this.entryId,
    required this.sourceId,
    required this.sourceType,
    required this.text,
    required this.cfiRange,
    required this.kind,
    required this.createdAt,
    this.context,
  });

  final String id;
  final String entryId;
  final String sourceId;
  final SourceType sourceType;
  final String text;
  final String? context;
  final String cfiRange;
  final DictionaryAnchorKind kind;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    entryId,
    sourceId,
    sourceType,
    text,
    context,
    cfiRange,
    kind,
    createdAt,
  ];
}
