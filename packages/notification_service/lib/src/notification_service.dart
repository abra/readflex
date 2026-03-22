/// Local push notification service for review reminders.
///
/// Wraps `flutter_local_notifications` in production.
/// Schedules notifications based on FSRS `nextReviewAt`.
abstract class NotificationService {
  /// Schedule a review reminder at [scheduledAt].
  Future<void> scheduleReviewReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  });

  /// Cancel a specific notification by [id].
  Future<void> cancel(int id);

  /// Cancel all scheduled notifications.
  Future<void> cancelAll();
}

/// Stub — does nothing.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> scheduleReviewReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
