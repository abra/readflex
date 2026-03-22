import 'package:flutter_test/flutter_test.dart';
import 'package:notification_service/notification_service.dart';

void main() {
  group('NoopNotificationService', () {
    test('scheduleReviewReminder completes without error', () async {
      const service = NoopNotificationService();
      await expectLater(
        service.scheduleReviewReminder(
          id: 1,
          title: 'Review',
          body: '5 cards due',
          scheduledAt: DateTime(2026, 1, 1),
        ),
        completes,
      );
    });

    test('cancel completes without error', () async {
      const service = NoopNotificationService();
      await expectLater(service.cancel(1), completes);
    });

    test('cancelAll completes without error', () async {
      const service = NoopNotificationService();
      await expectLater(service.cancelAll(), completes);
    });
  });
}
