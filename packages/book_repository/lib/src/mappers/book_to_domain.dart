import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

extension BookToDomain on BooksTableData {
  /// Maps a storage row to a domain [Book], resolving relative file paths
  /// against the per-book directory `booksDir/<id>/`.
  Book toDomainModel({required Directory booksDir}) {
    final bookDir = p.join(booksDir.path, id);

    return Book(
      id: id,
      title: title,
      author: author,
      coverImagePath: coverImagePath != null
          ? p.join(bookDir, coverImagePath!)
          : null,
      format: BookFormat.from(format),
      filePath: p.join(bookDir, filePath),
      totalLocations: totalLocations,
      currentLocation: currentLocation,
      currentCfi: currentCfi,
      readingProgress: readingProgress,
      addedAt: DateTime.tryParse(addedAt) ?? _epoch,
      lastOpenedAt: lastOpenedAt != null
          ? DateTime.tryParse(lastOpenedAt!)
          : null,
      isFinished: isFinished,
    );
  }
}
