// Domain models, enums, exceptions and contracts shared across features.
//
// Features import this package to access common types without depending
// on each other. Concrete implementations are wired in composition.dart.

export 'src/exceptions/not_found_exception.dart';
export 'src/exceptions/storage_exception.dart';
export 'src/models/article.dart';
export 'src/models/book.dart';
export 'src/models/book_format.dart';
export 'src/models/creation_source.dart';
export 'src/models/dictionary_entry.dart';
export 'src/models/flashcard.dart';
export 'src/models/fsrs_card_data.dart';
export 'src/models/highlight.dart';
export 'src/models/highlight_color.dart';
export 'src/models/rating.dart';
export 'src/models/review_log.dart';
export 'src/models/source_type.dart';
