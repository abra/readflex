/// What to do with the data the user produced while reading a book when
/// the book itself is deleted.
///
/// `keepLearningData` preserves saved words and their review state, plus
/// legacy flashcard rows, when the book is removed.
/// `deleteEverything` also removes that learning content and its review rows.
/// Historical review logs remain in either scope.
enum BookDeletionScope { keepLearningData, deleteEverything }
