import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:domain_models/domain_models.dart';

extension BookToStorage on Book {
  BooksTableCompanion toStorageModel() => BooksTableCompanion(
    id: Value(id),
    title: Value(title),
    author: Value(author),
    coverImagePath: Value(coverImagePath),
    format: Value(format.name),
    filePath: Value(filePath),
    totalLocations: Value(totalLocations),
    currentLocation: Value(currentLocation),
    readingProgress: Value(readingProgress),
    addedAt: Value(addedAt.toIso8601String()),
    lastOpenedAt: Value(lastOpenedAt?.toIso8601String()),
    isFinished: Value(isFinished),
  );
}
