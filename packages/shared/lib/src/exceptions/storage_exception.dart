/// Thrown when a storage operation fails unexpectedly.
class StorageException implements Exception {
  const StorageException({this.cause});

  final Object? cause;

  @override
  String toString() => 'StorageException: $cause';
}
