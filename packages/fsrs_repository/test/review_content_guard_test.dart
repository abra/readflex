import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late FsrsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = FsrsRepository(database: db);
  });
  tearDown(() => db.close());

  for (final type in [ReviewableType.dictionary, ReviewableType.highlight]) {
    test(
      'rejects a missing ${type.name} without tracking or a review log',
      () async {
        await expectLater(
          repository.recordReview(
            itemId: 'missing',
            itemType: type,
            rating: Rating.good,
          ),
          throwsA(
            isA<NotFoundException>().having((e) => e.id, 'id', 'missing'),
          ),
        );

        expect(await repository.getReviewState('missing'), isNull);
        expect(await db.reviewItemsDao.reviewLogCount(), 0);
        expect(await repository.getDueItemCount(), 0);
      },
    );
  }

  test('an image-area highlight cannot acquire text-review tracking', () async {
    await db.highlightsDao.insertHighlight(
      HighlightsTableCompanion.insert(
        id: 'area',
        sourceId: 'comic',
        sourceType: 'book',
        kind: const Value('imageArea'),
        highlightText: '',
        createdAt: DateTime.utc(2026).toIso8601String(),
      ),
    );

    await expectLater(
      repository.recordReview(
        itemId: 'area',
        itemType: ReviewableType.highlight,
        rating: Rating.good,
      ),
      throwsA(isA<NotFoundException>()),
    );
    expect(await repository.getReviewState('area'), isNull);
    expect(await db.reviewItemsDao.reviewLogCount(), 0);
  });

  test('content lookup failures remain StorageException', () async {
    await db.customStatement('DROP TABLE highlights_table');
    await expectLater(
      repository.recordReview(
        itemId: 'highlight',
        itemType: ReviewableType.highlight,
        rating: Rating.good,
      ),
      throwsA(isA<StorageException>()),
    );
    expect(await db.reviewItemsDao.reviewLogCount(), 0);
  });
}
