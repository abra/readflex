import 'package:article_parser/article_parser.dart';
import 'package:book_repository/book_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ImportArticleStatus { idle, loading, success, failure }

final class ImportArticleState extends Equatable {
  const ImportArticleState({
    this.status = ImportArticleStatus.idle,
    this.errorMessage,
  });

  final ImportArticleStatus status;
  final String? errorMessage;

  ImportArticleState copyWith({
    ImportArticleStatus? status,
    String? errorMessage,
  }) => ImportArticleState(
    status: status ?? this.status,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [status, errorMessage];
}

class ImportArticleCubit extends Cubit<ImportArticleState> {
  ImportArticleCubit({
    required ArticleParser articleParser,
    required BookRepository bookRepository,
  }) : _parser = articleParser,
       _bookRepository = bookRepository,
       super(const ImportArticleState());

  final ArticleParser _parser;
  final BookRepository _bookRepository;

  Future<void> importUrl(String url) async {
    if (url.trim().isEmpty) {
      emit(
        state.copyWith(
          status: ImportArticleStatus.failure,
          errorMessage: 'Please enter a URL',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ImportArticleStatus.loading));

    try {
      final parsed = await _parser.parse(url.trim());

      await _bookRepository.addArticle(
        title: parsed.title,
        url: url.trim(),
        cleanedHtml: parsed.cleanedHtml,
        siteName: parsed.siteName,
        coverImageUrl: parsed.coverImageUrl,
        estimatedWordCount: parsed.estimatedWordCount,
      );

      emit(state.copyWith(status: ImportArticleStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: ImportArticleStatus.failure,
          errorMessage: 'Failed to import article',
        ),
      );
    }
  }
}
