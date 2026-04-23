import 'package:drift/drift.dart';

/// Drift schema for flashcards. Cards are grouped by [deckId]; optional
/// [sourceHighlightId] backlinks to the highlight a card was generated
/// from. FSRS review state lives separately in `review_items_table`.
class FlashcardsTable extends Table {
  TextColumn get id => text()();

  TextColumn get deckId => text()();

  TextColumn get front => text()();

  TextColumn get back => text()();

  TextColumn get hint => text().nullable()();

  TextColumn get sourceHighlightId => text().nullable()();

  TextColumn get creationSource => text().withDefault(
    const Constant('manual'),
  )(); // manual, aiHighlight, aiSelection
  TextColumn get createdAt => text()(); // ISO 8601

  @override
  Set<Column> get primaryKey => {id};
}
