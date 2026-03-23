/// Thrown when an entity with the given [id] is not found in storage.
class NotFoundException implements Exception {
  const NotFoundException(this.id, [this.entityType = 'Entity']);

  final String id;
  final String entityType;

  @override
  String toString() => 'NotFoundException: $entityType with id "$id" not found';
}
