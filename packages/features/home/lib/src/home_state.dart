part of 'home_bloc.dart';

enum HomeStatus { initial, loading, success, failure }

final class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.recentBooks = const [],
    this.recentArticles = const [],
    this.totalHighlights = 0,
    this.dueFlashcards = 0,
  });

  final HomeStatus status;
  final List<Book> recentBooks;
  final List<Article> recentArticles;
  final int totalHighlights;
  final int dueFlashcards;

  int get totalBooks => recentBooks.length;
  int get totalArticles => recentArticles.length;
  int get totalSources => totalBooks + totalArticles;

  /// Up to 5 most recently opened or added items.
  List<Object> get recentItems {
    final all = <({DateTime date, Object item})>[
      for (final b in recentBooks) (date: b.lastOpenedAt ?? b.addedAt, item: b),
      for (final a in recentArticles)
        (date: a.lastOpenedAt ?? a.addedAt, item: a),
    ];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all.take(5).map((e) => e.item).toList();
  }

  HomeState copyWith({
    HomeStatus? status,
    List<Book>? recentBooks,
    List<Article>? recentArticles,
    int? totalHighlights,
    int? dueFlashcards,
  }) => HomeState(
    status: status ?? this.status,
    recentBooks: recentBooks ?? this.recentBooks,
    recentArticles: recentArticles ?? this.recentArticles,
    totalHighlights: totalHighlights ?? this.totalHighlights,
    dueFlashcards: dueFlashcards ?? this.dueFlashcards,
  );

  @override
  List<Object?> get props => [
    status,
    recentBooks,
    recentArticles,
    totalHighlights,
    dueFlashcards,
  ];
}
