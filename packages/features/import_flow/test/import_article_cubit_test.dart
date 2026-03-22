import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/src/import_article_cubit.dart';

import 'helpers/fake_article_parser.dart';
import 'helpers/fake_article_repository.dart';

void main() {
  group('ImportArticleCubit', () {
    late FakeArticleParser parser;
    late FakeArticleRepository repository;

    setUp(() {
      parser = FakeArticleParser();
      repository = FakeArticleRepository();
    });

    blocTest<ImportArticleCubit, ImportArticleState>(
      'emits loading then success on valid URL',
      build: () => ImportArticleCubit(
        articleParser: parser,
        articleRepository: repository,
      ),
      act: (cubit) => cubit.importUrl('https://example.com/article'),
      expect: () => [
        const ImportArticleState(status: ImportArticleStatus.loading),
        const ImportArticleState(status: ImportArticleStatus.success),
      ],
      verify: (_) {
        expect(repository.addedArticles, hasLength(1));
        expect(repository.addedArticles.first.title, 'Parsed Title');
      },
    );

    blocTest<ImportArticleCubit, ImportArticleState>(
      'emits failure on empty URL',
      build: () => ImportArticleCubit(
        articleParser: parser,
        articleRepository: repository,
      ),
      act: (cubit) => cubit.importUrl(''),
      expect: () => [
        const ImportArticleState(
          status: ImportArticleStatus.failure,
          errorMessage: 'Please enter a URL',
        ),
      ],
    );

    blocTest<ImportArticleCubit, ImportArticleState>(
      'emits failure when parser throws',
      setUp: () => parser.shouldThrow = true,
      build: () => ImportArticleCubit(
        articleParser: parser,
        articleRepository: repository,
      ),
      act: (cubit) => cubit.importUrl('https://example.com'),
      expect: () => [
        const ImportArticleState(status: ImportArticleStatus.loading),
        const ImportArticleState(
          status: ImportArticleStatus.failure,
          errorMessage: 'Failed to import article',
        ),
      ],
    );

    blocTest<ImportArticleCubit, ImportArticleState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => ImportArticleCubit(
        articleParser: parser,
        articleRepository: repository,
      ),
      act: (cubit) => cubit.importUrl('https://example.com'),
      expect: () => [
        const ImportArticleState(status: ImportArticleStatus.loading),
        const ImportArticleState(
          status: ImportArticleStatus.failure,
          errorMessage: 'Failed to import article',
        ),
      ],
    );
  });
}
