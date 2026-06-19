/// What to do with the data the user produced while reading a book when
/// the book itself is deleted.
///
/// `keepLearningData` is the safe default — it preserves dormant learning
/// rows so removing a book does not destroy user-created data that may be
/// restored later.
/// `deleteEverything` is opt-in for users who want a clean slate.
enum BookDeletionScope { keepLearningData, deleteEverything }
