import 'package:equatable/equatable.dart' show Equatable;

import 'creation_source.dart';

/// A flashcard for spaced repetition review.
class Flashcard extends Equatable {
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.hint,
    this.sourceHighlightId,
    this.creationSource = CreationSource.manual,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? hint;
  final String? sourceHighlightId;
  final CreationSource creationSource;
  final DateTime createdAt;

  static const _absent = Object();

  Flashcard copyWith({
    String? front,
    String? back,
    Object? hint = _absent,
    Object? sourceHighlightId = _absent,
    CreationSource? creationSource,
  }) => Flashcard(
    id: id,
    deckId: deckId,
    front: front ?? this.front,
    back: back ?? this.back,
    hint: hint == _absent ? this.hint : hint as String?,
    sourceHighlightId: sourceHighlightId == _absent
        ? this.sourceHighlightId
        : sourceHighlightId as String?,
    creationSource: creationSource ?? this.creationSource,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    deckId,
    front,
    back,
    hint,
    sourceHighlightId,
    creationSource,
    createdAt,
  ];
}
