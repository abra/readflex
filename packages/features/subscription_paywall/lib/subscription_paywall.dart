/// Subscription paywall feature: modal bottom sheet that upsells Readflex
/// Premium and triggers the purchase flow placeholder.
///
/// Not wired into the router — call `showSubscriptionPaywallSheet` from any
/// surface that gates a premium feature (e.g. the pro badge in Profile or a
/// lock icon tap anywhere in the app).
library;

export 'src/subscription_paywall_sheet.dart';
