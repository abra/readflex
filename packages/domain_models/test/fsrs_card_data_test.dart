import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 4, 1);
  final later = DateTime(2026, 4, 10);

  FsrsCardData data() => FsrsCardData(
    state: FsrsState.review,
    stability: 5.5,
    difficulty: 3.2,
    retrievability: 0.9,
    reps: 4,
    lapses: 1,
    lastReviewAt: now,
    nextReviewAt: later,
    scheduledDays: 9,
    elapsedDays: 3,
  );

  group('FsrsCardData copyWith()', () {
    test('preserves all fields when no arguments', () {
      final d = data();
      expect(d.copyWith(), equals(d));
    });

    test('updates scalar fields', () {
      final d = data().copyWith(
        state: FsrsState.learning,
        stability: 1.0,
        difficulty: 2.0,
        retrievability: 0.5,
        reps: 10,
        lapses: 3,
        scheduledDays: 7,
        elapsedDays: 2,
      );
      expect(d.state, FsrsState.learning);
      expect(d.stability, 1.0);
      expect(d.difficulty, 2.0);
      expect(d.retrievability, 0.5);
      expect(d.reps, 10);
      expect(d.lapses, 3);
      expect(d.scheduledDays, 7);
      expect(d.elapsedDays, 2);
    });

    test('clears lastReviewAt when null is passed explicitly', () {
      final d = data().copyWith(lastReviewAt: null);
      expect(d.lastReviewAt, isNull);
    });

    test('clears nextReviewAt when null is passed explicitly', () {
      final d = data().copyWith(nextReviewAt: null);
      expect(d.nextReviewAt, isNull);
    });

    test('preserves nullable dates when omitted', () {
      final d = data().copyWith(stability: 99.0);
      expect(d.lastReviewAt, now);
      expect(d.nextReviewAt, later);
    });
  });

  group('FsrsCardData equality', () {
    test('same fields are equal', () {
      expect(data(), equals(data()));
    });

    test('different state are not equal', () {
      expect(
        data(),
        isNot(equals(data().copyWith(state: FsrsState.newCard))),
      );
    });

    test('different stability are not equal', () {
      expect(data(), isNot(equals(data().copyWith(stability: 0.0))));
    });
  });

  group('FsrsCardData defaults', () {
    test('default constructor has expected values', () {
      const d = FsrsCardData();
      expect(d.state, FsrsState.newCard);
      expect(d.stability, 0.0);
      expect(d.difficulty, 0.0);
      expect(d.retrievability, 0.0);
      expect(d.reps, 0);
      expect(d.lapses, 0);
      expect(d.lastReviewAt, isNull);
      expect(d.nextReviewAt, isNull);
      expect(d.scheduledDays, 0);
      expect(d.elapsedDays, 0);
    });
  });
}
