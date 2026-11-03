import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queue snapshots compare both counts and deadlines', () {
    final deadline = DateTime.utc(2026, 11, 4, 7, 5);
    final status = ReviewQueueStatus(dueCount: 2, nextReviewAt: deadline);
    expect(status, ReviewQueueStatus(dueCount: 2, nextReviewAt: deadline));
    expect(
      status,
      isNot(ReviewQueueStatus(dueCount: 1, nextReviewAt: deadline)),
    );
    expect(
      status,
      isNot(
        ReviewQueueStatus(
          dueCount: 2,
          nextReviewAt: deadline.add(const Duration(minutes: 1)),
        ),
      ),
    );
    expect(status, isNot(const ReviewQueueStatus(dueCount: 2)));
  });

  test('no future deadline is a valid queue snapshot', () {
    expect(const ReviewQueueStatus(dueCount: 0).nextReviewAt, isNull);
    expect(
      const ReviewQueueStatus(dueCount: 0),
      const ReviewQueueStatus(dueCount: 0),
    );
  });
}
