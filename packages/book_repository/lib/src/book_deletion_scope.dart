/// What to do with the data the user produced while reading a book when
/// the book itself is deleted.
///
/// `keepLearningData` is the safe default — it preserves saved words and
/// flashcards as standalone learning material, which is what most readers
/// expect ("I'm done with this book but I still want my vocabulary").
/// `deleteEverything` is opt-in for users who want a clean slate.
enum BookDeletionScope { keepLearningData, deleteEverything }
