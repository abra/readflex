import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

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
    addedAt: DateTime.tryParse(addedAt) ?? _epoch,
    lastOpenedAt: lastOpenedAt != null
        ? DateTime.tryParse(lastOpenedAt!)
        : null,
    isFinished: isFinished,
  );
}
