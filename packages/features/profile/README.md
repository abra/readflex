# profile

Profile tab: account status, appearance preferences, reading preferences,
and entry points for auth, premium, and developer tooling.

## Public API

| Symbol          | Kind              | Purpose                               |
|-----------------|-------------------|---------------------------------------|
| `ProfileScreen` | `StatelessWidget` | The Profile tab at `/profile`         |

### ProfileScreen props

| Prop                    | Type                    | Purpose                                     |
|-------------------------|-------------------------|---------------------------------------------|
| `authService`           | `AuthService`           | Reads auth status, triggers sign-out        |
| `subscriptionService`   | `SubscriptionService`   | Reads premium status                        |
| `preferencesService`    | `PreferencesService`    | Reads/writes theme mode + reader appearance |
| `onSignInPressed`       | `VoidCallback`          | Navigate to sign-in flow                    |
| `onPremiumPressed`      | `VoidCallback`          | Open `subscription_paywall` sheet           |
| `onDesignSystemPressed` | `VoidCallback`          | Open `/design-system` dev screen            |
| `appVersion`            | `String`                | From `PackageInfo`                          |

All navigation is injected — this feature does not import the router.

## Architecture

Two cubits, both provided via `MultiBlocProvider`:

- `ProfileCubit` — loads `authStatus`, `email`, `subscriptionStatus` on
  screen open; exposes `signOut()`. Sign-out failures are reported via
  `addError` (non-fatal for app state) and the loading flag is reset.
- `ProfileAppearanceCubit` — mirrors the `PreferencesService` snapshot
  (theme mode + `ReaderAppearance`). Offers `setThemeMode`,
  `setReaderTheme`, `setReaderFont`, plus preview/commit pairs for
  `textScale` and `lineHeight` so sliders can feel live without
  hammering storage on every tick. Every writer performs an optimistic
  emit and rolls back on failure.

The "Font & Text Size" settings row opens an in-package
`_FontSheet` via `showAppBottomSheet`, passing the existing
`ProfileAppearanceCubit` down with `BlocProvider.value`.

## Dependencies

- `AuthService` — auth state and sign-out.
- `SubscriptionService` — premium flag for the PRO badge.
- `PreferencesService` — reactive snapshot of theme + reader appearance.
- `component_library` — theme, settings widgets, bottom-sheet shell.

## Sections rendered

Appearance (theme mode), Reading (font & text, translation language),
General (sync, offline, notifications, privacy), About (version, terms),
Developer (design system), and a sign-out row that is hidden for
unauthenticated users.
