import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

extension BookToDomain on BooksTableData {
  Book toDomainModel() => Book(
    id: id,
    title: title,
    author: author,
    coverImagePath: coverImagePath,
    format: BookFormat.from(format),
    filePath: filePath,
    totalLocations: totalLocations,
    currentLocation: currentLocation,
    readingProgress: readingProgress,
    addedAt: DateTime.parse(addedAt),
    lastOpenedAt: lastOpenedAt != null ? DateTime.parse(lastOpenedAt!) : null,
    isFinished: isFinished,
  );
}
