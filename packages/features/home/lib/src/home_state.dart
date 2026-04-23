part of 'home_bloc.dart';

enum HomeStatus { initial, loading, success, failure }

/// Snapshot of Home-tab data: recent books/articles, an interleaved list of
/// the 5 most recent items (pre-sorted in the bloc), and the totals the
/// stats row surfaces (highlights, due flashcards, derived sources count).
class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.recentBooks = const [],
    this.recentArticles = const [],
    this.recentItems = const [],
    this.totalHighlights = 0,
    this.dueFlashcards = 0,
  });

  final HomeStatus status;
  final List<Book> recentBooks;
  final List<Article> recentArticles;

  /// Up to 5 most recently opened or added items (pre-computed in bloc).
  final List<Object> recentItems;

  final int totalHighlights;
  final int dueFlashcards;

  int get totalBooks => recentBooks.length;

  int get totalArticles => recentArticles.length;

  int get totalSources => totalBooks + totalArticles;

  HomeState copyWith({
    HomeStatus? status,
    List<Book>? recentBooks,
    List<Article>? recentArticles,
    List<Object>? recentItems,
    int? totalHighlights,
    int? dueFlashcards,
  }) => HomeState(
    status: status ?? this.status,
    recentBooks: recentBooks ?? this.recentBooks,
    recentArticles: recentArticles ?? this.recentArticles,
    recentItems: recentItems ?? this.recentItems,
    totalHighlights: totalHighlights ?? this.totalHighlights,
    dueFlashcards: dueFlashcards ?? this.dueFlashcards,
  );

  @override
  List<Object?> get props => [
    status,
    recentBooks,
    recentArticles,
    recentItems,
    totalHighlights,
    dueFlashcards,
  ];
}
