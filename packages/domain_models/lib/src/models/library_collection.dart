import 'package:equatable/equatable.dart';

/// A user-created collection of library sources.
///
/// Smart collections such as "author" or "site" are derived from source
/// metadata and do not use this model; this model represents persisted manual
/// collections only.
class LibraryCollection extends Equatable {
  const LibraryCollection({
    required this.id,
    required this.name,
    required this.sourceCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int sourceCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, name, sourceCount, createdAt, updatedAt];
}
