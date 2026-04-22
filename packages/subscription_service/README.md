# subscription_service

Premium subscription status. Features consult this to decide whether to
unlock a premium action or route the user to the paywall (lock icon → tap →
`subscription_paywall` bottom sheet).

The real implementation will wrap in-app purchases (RevenueCat or
platform-native). Development wiring uses `NoopSubscriptionService`
(always `free`).

## Public API

| Symbol                      | Type           | Purpose                                 |
|-----------------------------|----------------|-----------------------------------------|
| `SubscriptionService`       | abstract class | Current status + refresh                |
| `NoopSubscriptionService`   | concrete       | Stub — always `free`, safe for dev      |
| `SubscriptionStatus`        | enum           | `free` / `premium`                      |

### Methods

- `SubscriptionStatus get status`
- `bool get isPremium` — convenience getter.
- `Future<void> refresh()` — re-check entitlement with the server.

## Usage

```dart
final subscription = context.dependencies.subscriptionService;

if (!subscription.isPremium) {
  showSubscriptionPaywall(context);
  return;
}
// ... run premium action
```

## Where it fits

Registered on `DependenciesContainer.subscriptionService` in
`lib/app/composition.dart`. Used by features that gate premium functionality
(AI-enriched translation, unlimited flashcards, etc.) and by the backend AI
service for server-side entitlement checks. Swap the stub for a real
implementation without touching callers — they depend on the interface only.
