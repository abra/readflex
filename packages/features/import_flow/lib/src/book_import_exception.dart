/// Why the engine refused a picked book: carried to the failure UI as
/// the import's reason, unlike other failures, which only log.
class BookImportException implements Exception {
  const BookImportException(this.message);

  final String message;

  @override
  String toString() => 'BookImportException: $message';
}
