# notification_service

Local push notification contract for future FSRS review reminders. The app
currently wires `NoopNotificationService`; no platform notification backend or
Profile toggle is active yet.

The future production implementation should wrap `flutter_local_notifications`
and schedule reminders from persisted FSRS `nextReviewAt` values.

## Public API

| Symbol                    | Type           | Purpose                                |
|---------------------------|----------------|----------------------------------------|
| `NotificationService`     | abstract class | Schedule / cancel local notifications  |
| `NoopNotificationService` | concrete       | Current no-op implementation           |

### Methods

- `Future<void> scheduleReviewReminder({int id, String title, String body, DateTime scheduledAt})`
- `Future<void> cancel(int id)`
- `Future<void> cancelAll()`

The `id` is the caller's responsibility (typically derived from the
reviewable item's id) so the same notification can be cancelled or rescheduled
deterministically.

## Intended usage

```dart
final notifications = context.dependencies.notificationService;

// Schedule next reminder after a review
await notifications.scheduleReviewReminder(
  id: dueCard.id.hashCode,
  title: 'Time to review',
  body: 'You have ${count} cards due',
  scheduledAt: dueCard.nextReviewAt,
);

// Clear pending reminders on sign-out
await notifications.cancelAll();
```

## Where it fits

Registered on `DependenciesContainer.notificationService` in
`lib/app/composition.dart`, currently as `NoopNotificationService`. The real
implementation will wrap `flutter_local_notifications`, request platform
permissions, and honor a future user preference before scheduling reminders.
