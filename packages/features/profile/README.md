# profile

Profile tab: account status, appearance preferences, reading and translation
preferences, plus entry points for auth and premium.

## Public API

| Symbol          | Kind              | Purpose                               |
|-----------------|-------------------|---------------------------------------|
| `ProfileScreen` | `StatelessWidget` | The Profile tab at `/profile`         |

### ProfileScreen props

| Prop                    | Type                    | Purpose                                     |
|-------------------------|-------------------------|---------------------------------------------|
| `authService`           | `AuthService`           | Reads auth status, triggers sign-out        |
| `subscriptionService`   | `SubscriptionService`   | Reads premium status                        |
| `preferencesService`    | `PreferencesService`    | Reads/writes theme, reader, and translation prefs |
| `onSignInPressed`       | `VoidCallback`          | Navigate to sign-in flow                    |
| `onPremiumPressed`      | `VoidCallback`          | Open `subscription_paywall` sheet           |
| `appVersion`            | `String`                | From `PackageInfo`                          |

All navigation is injected — this feature does not import the router.

## Architecture

Three cubits, provided via `MultiBlocProvider`:

- `ProfileCubit` — loads `authStatus`, `email`, `subscriptionStatus` on
  screen open; exposes `signOut()`. Sign-out failures are reported via
  `addError` (non-fatal for app state) and the loading flag is reset.
- `ProfileAppearanceCubit` — mirrors the `PreferencesService` snapshot
  (theme mode + `ReaderAppearance`). Offers `setThemeMode`,
  `setReaderTheme`, `setReaderFont`, plus preview/commit pairs for
  `textScale` and `lineHeight` so sliders can feel live without
  hammering storage on every tick. Every writer performs an optimistic
  emit and rolls back on failure.
- `ProfileTranslationCubit` — mirrors translation source/target language
  preferences. `null` source means automatic source-language detection; target
  language is always explicit.

The "Font & Text Size" settings row opens an in-package
`_FontSheet` via `showAppBottomSheet`, passing the existing
`ProfileAppearanceCubit` down with `BlocProvider.value`.
The source and target language rows open `_LanguageSelectionSheet`; source
includes an Auto option, target does not.

## Dependencies

- `AuthService` — auth state and sign-out.
- `SubscriptionService` — premium flag for the PRO badge.
- `PreferencesService` — reactive snapshot of theme, reader appearance, and
  translation language preferences.
- `component_library` — theme, settings widgets, bottom-sheet shell.

## Sections rendered

Appearance (theme mode), Reading (font & text, translation language),
General (sync, offline, notifications, privacy), About (version, terms), and a
sign-out row that is hidden for unauthenticated users.
