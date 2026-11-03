import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 11, 4, 7);
  final soon = now.add(const Duration(minutes: 5));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(
    String id, {
    ReviewableType type = ReviewableType.dictionary,
    DateTime? due,
  }) => db.reviewItemsDao.insertItem(
    ReviewItemsTableCompanion(
      itemId: Value(id),
      itemType: Value(type.toStorageString()),
      nextReviewAt: Value(due?.toUtc().toIso8601String()),
    ),
  );

  test('an empty queue has no deadline', () async {
    final repository = FsrsRepository(database: db, clock: () => now);
    expect(
      await repository.getReviewQueueStatus(),
      const ReviewQueueStatus(dueCount: 0),
    );
  });

  test('compares in UTC and returns a UTC future deadline', () async {
    final localClock = DateTime.parse('2026-11-04T12:00:00+05:00');
    final repository = FsrsRepository(database: db, clock: () => localClock);
    await insert('new');
    await insert('overdue', due: now.subtract(const Duration(minutes: 1)));
    await insert('now', due: now);
    await insert('future', due: soon);

    final status = await repository.getReviewQueueStatus();
    expect(status.dueCount, 3);
    expect(status.nextReviewAt, soon);
    expect(status.nextReviewAt!.isUtc, isTrue);
  });

  test('uses one clock snapshot across the due count and deadline', () async {
    var reads = 0;
    final repository = FsrsRepository(
      database: db,
      clock: () => reads++ == 0 ? now : soon,
    );
    await insert('future', due: soon);

    expect(
      await repository.getReviewQueueStatus(),
      ReviewQueueStatus(dueCount: 0, nextReviewAt: soon),
    );
    expect(reads, 1);
  });

  test('active types exclude legacy rows and disabled highlights', () async {
    final repository = FsrsRepository(database: db, clock: () => now);
    await insert('word');
    await insert('word-future', due: soon);
    await insert('highlight', type: ReviewableType.highlight);
    await insert(
      'highlight-future',
      type: ReviewableType.highlight,
      due: now.add(const Duration(minutes: 2)),
    );
    await insert('legacy', type: ReviewableType.flashcard);
    await insert(
      'legacy-future',
      type: ReviewableType.flashcard,
      due: now.add(const Duration(minutes: 1)),
    );

    expect(
      await repository.getReviewQueueStatus(
        types: {ReviewableType.dictionary, ReviewableType.highlight},
      ),
      ReviewQueueStatus(
        dueCount: 2,
        nextReviewAt: now.add(const Duration(minutes: 2)),
      ),
    );
    expect(
      await repository.getReviewQueueStatus(types: {ReviewableType.dictionary}),
      ReviewQueueStatus(dueCount: 1, nextReviewAt: soon),
    );
    expect(
      await repository.getReviewQueueStatus(),
      ReviewQueueStatus(
        dueCount: 3,
        nextReviewAt: now.add(const Duration(minutes: 1)),
      ),
    );
    expect(
      await repository.getReviewQueueStatus(types: {}),
      const ReviewQueueStatus(dueCount: 0),
    );
  });

  test('storage failures use the repository exception boundary', () async {
    final repository = FsrsRepository(database: db, clock: () => now);
    await db.customStatement('DROP TABLE review_items_table');
    await expectLater(
      repository.getReviewQueueStatus(),
      throwsA(isA<StorageException>()),
    );
  });
}
