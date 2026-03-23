import 'package:equatable/equatable.dart' show Equatable;

import 'book_format.dart';

/// A book entity stored in the user's library.
final class Book extends Equatable {
  const Book({
    required this.id,
    required this.title,
    required this.filePath,
    required this.format,
    required this.addedAt,
    this.author,
    this.coverImagePath,
    this.totalLocations = 0,
    this.currentLocation = 0,
    this.readingProgress = 0.0,
    this.lastOpenedAt,
    this.isFinished = false,
  });

  final String id;
  final String title;
  final String? author;
  final String? coverImagePath;
  final BookFormat format;
  final String filePath;
  final int totalLocations;
  final int currentLocation;
  final double readingProgress;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final bool isFinished;

  static const _absent = Object();

  Book copyWith({
    String? title,
    Object? author = _absent,
    Object? coverImagePath = _absent,
    BookFormat? format,
    String? filePath,
    int? totalLocations,
    int? currentLocation,
    double? readingProgress,
    Object? lastOpenedAt = _absent,
    bool? isFinished,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author == _absent ? this.author : author as String?,
    coverImagePath: coverImagePath == _absent
        ? this.coverImagePath
        : coverImagePath as String?,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    totalLocations: totalLocations ?? this.totalLocations,
    currentLocation: currentLocation ?? this.currentLocation,
    readingProgress: readingProgress ?? this.readingProgress,
    addedAt: addedAt,
    lastOpenedAt: lastOpenedAt == _absent
        ? this.lastOpenedAt
        : lastOpenedAt as DateTime?,
    isFinished: isFinished ?? this.isFinished,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    coverImagePath,
    format,
    filePath,
    totalLocations,
    currentLocation,
    readingProgress,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
}
