/// What to do with the data the user produced while reading a book when
/// the book itself is deleted.
///
/// `keepLearningData` preserves saved words and their review state, plus
/// legacy flashcard rows, when the book is removed.
/// `deleteEverything` is opt-in for users who want a clean slate.
enum BookDeletionScope { keepLearningData, deleteEverything }
