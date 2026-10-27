import 'package:flutter_test/flutter_test.dart';
import 'package:review_scheduler/review_scheduler.dart';

void main() {
  const day = StudyDay();

  group('StudyDay', () {
    test('starts at 04:00 local by default', () {
      expect(day.startHour, 4);
      expect(const StudyDay(startHour: 0).startHour, 0);
    });

    test('an hour before the boundary still belongs to the day before', () {
      final lateNight = DateTime(2026, 3, 10, 3, 59);
      final morning = DateTime(2026, 3, 10, 4);

      expect(day.dateOf(lateNight), DateTime.utc(2026, 3, 9));
      expect(day.dateOf(morning), DateTime.utc(2026, 3, 10));
      expect(day.between(lateNight, morning), 1);
    });

    test('midnight does not end a day', () {
      final evening = DateTime(2026, 3, 9, 23, 50);
      final afterMidnight = DateTime(2026, 3, 10, 0, 10);

      expect(day.between(evening, afterMidnight), 0);
      expect(day.dateOf(afterMidnight), DateTime.utc(2026, 3, 9));
    });

    test('counts whole days across months and backwards', () {
      final a = DateTime(2026, 1, 31, 12);
      final b = DateTime(2026, 3, 2, 2);

      expect(day.between(a, b), 29);
      expect(day.between(b, a), -29);
    });

    test('reads instants in UTC by their local day', () {
      final local = DateTime(2026, 6, 15, 5);
      expect(day.dateOf(local.toUtc()), day.dateOf(local));
      expect(day.between(local.toUtc(), local.add(const Duration(days: 2))), 2);
    });

    test('a day begins at its start hour', () {
      final start = day.startOf(DateTime(2026, 3, 10, 1));
      expect(start, DateTime(2026, 3, 9, 4));
      expect(day.startOf(DateTime(2026, 3, 10, 22)), DateTime(2026, 3, 10, 4));
    });

    test('a card due in N days comes due when that day starts', () {
      final reviewed = DateTime(2026, 3, 9, 23, 50);
      expect(day.startAfter(reviewed, 1), DateTime(2026, 3, 10, 4));
      expect(day.startAfter(reviewed, 30), DateTime(2026, 4, 8, 4));
      expect(day.between(reviewed, day.startAfter(reviewed, 30)), 30);
    });

    test('a custom start hour moves the boundary', () {
      const midnight = StudyDay(startHour: 0);
      final lateNight = DateTime(2026, 3, 10, 0, 30);
      expect(midnight.dateOf(lateNight), DateTime.utc(2026, 3, 10));
      expect(midnight.startOf(lateNight), DateTime(2026, 3, 10));
    });
  });
}
