# subscription_paywall

Full-screen bottom sheet that upsells Readflex Premium and triggers the
purchase flow. Not a route — callers open it imperatively through the
exported launcher, which is used wherever a premium feature is gated
(lock icons, the PRO row in Profile, upsell CTAs).

## Public API

| Symbol                             | Kind              | Purpose                                     |
|------------------------------------|-------------------|---------------------------------------------|
| `SubscriptionPaywallSheet`         | `StatelessWidget` | Sheet body that drives the purchase cubit   |
| `showSubscriptionPaywallSheet(…)`  | function          | Opens the sheet via `showAppBottomSheet`    |

### showSubscriptionPaywallSheet

```dart
void showSubscriptionPaywallSheet(
  BuildContext context, {
  required SubscriptionService subscriptionService,
});
```

## Architecture

- `SubscriptionPaywallCubit` — two operations: `load()` (reads the
  current `isPremium` flag) and `purchase()` (placeholder that currently
  just refreshes `SubscriptionService` and checks if the user has become
  premium; the real platform purchase flow plugs in here). Status flow:
  `idle → purchasing → success` with a `failure` branch that surfaces an
  inline error message.
- `SubscriptionPaywallState` — `status` + `isPremium`. The sheet view
  listens for `success` and pops itself.

## Dependencies

- `SubscriptionService` — reads premium status and performs the refresh
  that stands in for a real StoreKit / Play Billing call.
- `component_library` — bottom-sheet shell, icons, buttons.

## Not a route

The sheet is intentionally kept out of `routing.dart`. Open it directly:

```dart
showSubscriptionPaywallSheet(
  context,
  subscriptionService: deps.subscriptionService,
);
```

Typical callers: Profile (tap PRO row), lock icons next to premium
features anywhere in the app.
