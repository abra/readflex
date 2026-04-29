part of 'home_bloc.dart';

enum HomeStatus { initial, loading, success, failure }

/// Snapshot of Home-tab data: recent books and the totals the stats row
/// surfaces (highlights, due flashcards).
class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.recentBooks = const [],
    this.totalHighlights = 0,
    this.dueFlashcards = 0,
  });

  final HomeStatus status;
  final List<Book> recentBooks;

  final int totalHighlights;
  final int dueFlashcards;

  int get totalBooks => recentBooks.length;

  int get totalSources => totalBooks;

  HomeState copyWith({
    HomeStatus? status,
    List<Book>? recentBooks,
    int? totalHighlights,
    int? dueFlashcards,
  }) => HomeState(
    status: status ?? this.status,
    recentBooks: recentBooks ?? this.recentBooks,
    totalHighlights: totalHighlights ?? this.totalHighlights,
    dueFlashcards: dueFlashcards ?? this.dueFlashcards,
  );

  @override
  List<Object?> get props => [
    status,
    recentBooks,
    totalHighlights,
    dueFlashcards,
  ];
}
