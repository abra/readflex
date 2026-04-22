# notification_service

Local push notifications for FSRS review reminders. Scheduled based on
`fsrsRepository.nextReviewAt`; users can toggle reminders in Profile.

Production implementation wraps `flutter_local_notifications`; development
uses `NoopNotificationService` (no-op).

## Public API

| Symbol                    | Type           | Purpose                                |
|---------------------------|----------------|----------------------------------------|
| `NotificationService`     | abstract class | Schedule / cancel local notifications  |
| `NoopNotificationService` | concrete       | Stub — does nothing, safe for dev      |

### Methods

- `Future<void> scheduleReviewReminder({int id, String title, String body, DateTime scheduledAt})`
- `Future<void> cancel(int id)`
- `Future<void> cancelAll()`

The `id` is the caller's responsibility (typically derived from the
reviewable item's id) so the same notification can be cancelled or rescheduled
deterministically.

## Usage

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
`lib/app/composition.dart`. Typically invoked from the FSRS repository /
practice feature after a review rating is recorded. The real implementation
will wrap `flutter_local_notifications`, request platform permissions, and
honor the user's Profile toggle.
