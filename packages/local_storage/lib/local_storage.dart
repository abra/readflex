/// Single Drift database (`readflex.db`) for the whole app: all tables,
/// DAOs, schema, and migrations. Repositories consume [AppDatabase] and
/// extract the DAO they need.
library;

export 'src/daos/books_dao.dart';
export 'src/daos/dictionary_dao.dart';
export 'src/daos/flashcards_dao.dart';
export 'src/daos/highlights_dao.dart';
export 'src/daos/review_items_dao.dart';
export 'src/database.dart';
