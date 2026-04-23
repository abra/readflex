/// Contract for scheduling local (on-device) push notifications that
/// remind the user to review due flashcards / highlights / dictionary
/// entries. The production implementation wraps
/// `flutter_local_notifications`; reminder times come from
/// `FsrsRepository.nextReviewAt`.
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

/// Stub [NotificationService] that silently discards every schedule/cancel
/// call. Used in tests and during development until the real
/// `flutter_local_notifications`-backed implementation is wired in.
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
