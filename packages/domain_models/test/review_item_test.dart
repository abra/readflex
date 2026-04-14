import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReviewItem item() => const ReviewItem(
    itemId: 'f1',
    itemType: ReviewableType.flashcard,
    sourceId: 'book-1',
    fsrs: FsrsCardData(
      state: FsrsState.review,
      stability: 5.0,
      difficulty: 3.0,
    ),
  );

  group('ReviewItem copyWith()', () {
    test('preserves id and type', () {
      final updated = item().copyWith(
        fsrs: const FsrsCardData(state: FsrsState.learning),
      );
      expect(updated.itemId, 'f1');
      expect(updated.itemType, ReviewableType.flashcard);
      expect(updated.sourceId, 'book-1');
      expect(updated.fsrs.state, FsrsState.learning);
    });

    test('preserves fsrs when omitted', () {
      final original = item();
      final copy = original.copyWith();
      expect(copy.fsrs, original.fsrs);
    });
  });

  group('ReviewItem equality', () {
    test('same fields are equal', () {
      expect(item(), equals(item()));
    });

    test('different itemId are not equal', () {
      final other = const ReviewItem(
        itemId: 'f2',
        itemType: ReviewableType.flashcard,
        sourceId: 'book-1',
        fsrs: FsrsCardData(
          state: FsrsState.review,
          stability: 5.0,
          difficulty: 3.0,
        ),
      );
      expect(item(), isNot(equals(other)));
    });

    test('different itemType are not equal', () {
      final other = const ReviewItem(
        itemId: 'f1',
        itemType: ReviewableType.highlight,
        sourceId: 'book-1',
        fsrs: FsrsCardData(
          state: FsrsState.review,
          stability: 5.0,
          difficulty: 3.0,
        ),
      );
      expect(item(), isNot(equals(other)));
    });

    test('null sourceId', () {
      const noSource = ReviewItem(
        itemId: 'f1',
        itemType: ReviewableType.flashcard,
        fsrs: FsrsCardData(),
      );
      expect(noSource.sourceId, isNull);
    });
  });
}
