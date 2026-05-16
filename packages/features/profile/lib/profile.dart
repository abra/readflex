// Profile feature: settings, auth status, appearance, and premium entry.
//
// Wires theme mode and reader appearance (font, text scale, line height,
// theme preset) through `PreferencesService`, reads auth state from
// `AuthService`, and surfaces premium status from `SubscriptionService`.
// Navigation callbacks (sign-in, paywall, design system) are injected by
// the composition root.

export 'src/profile_screen.dart';
