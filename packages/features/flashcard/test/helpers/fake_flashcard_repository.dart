import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flashcard_repository/flashcard_repository.dart';

class FakeFlashcardRepository implements FlashcardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  /// When set, `addFlashcard` blocks on this completer's future before
  /// resolving. Tests use this to simulate "user dismissed sheet
  /// mid-save" by closing the cubit while the call is in flight.
  Completer<void>? awaitGate;

  final List<Flashcard> flashcards = [];

  @override
  Future<Flashcard> addFlashcard({
    required String deckId,
    required String front,
    required String back,
    String? hint,
    String? sourceHighlightId,
    CreationSource creationSource = CreationSource.manual,
  }) async {
    if (awaitGate != null) await awaitGate!.future;
    if (shouldThrow) throw Exception('addFlashcard failed');

    final card = Flashcard(
      id: 'fc-${flashcards.length + 1}',
      deckId: deckId,
      front: front,
      back: back,
      hint: hint,
      sourceHighlightId: sourceHighlightId,
      creationSource: creationSource,
      createdAt: DateTime.now(),
    );
    flashcards.add(card);
    return card;
  }
}
