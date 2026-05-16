# preferences_service

User preferences: theme mode, locale, reader appearance, catalog layout, and
onboarding / setup flags. Backed by `shared_preferences` (JSON blob under a
single key) and exposed to the UI via a reactive stream and an
`InheritedModel` scope.

This is **not** where auth tokens live — those go through `auth_service` /
`flutter_secure_storage`.

## Public API

| Symbol                          | Type             | Purpose                                                            |
|---------------------------------|------------------|--------------------------------------------------------------------|
| `Preferences`                   | data class       | Immutable snapshot of all preferences, with `copyWith`             |
| `ReaderAppearancePreferences`   | data class       | Reader-only view over `Preferences` (theme, font, scale, etc.)    |
| `PreferencesService`            | concrete         | Loads, streams, and persists `Preferences`                         |
| `PreferencesStorage`            | concrete         | Thin `SharedPreferences` wrapper                                   |
| `PreferencesRepository`         | concrete         | JSON (de)serialization + locale resolution                         |
| `PreferencesScope`              | StatelessWidget  | `InheritedModel` with `themeMode` / `readerAppearance` aspects     |

### What is stored

| Field                      | Type        | Default     |
|----------------------------|-------------|-------------|
| `themeMode`                | `ThemeMode` | `system`    |
| `locale`                   | `Locale`    | platform    |
| `catalogLayoutMode`        | `String`    | `'grid'`    |
| `readerThemeId`            | `String`    | `'paper'`   |
| `readerFontId`             | `String`    | `'serif'`   |
| `readerLayoutId`           | `String`    | `'standard'`|
| `readerTextScale`          | `double`    | `1.0`       |
| `readerLineHeight`         | `double`    | `1.55`      |
| `readerSideMargin`         | `double`    | `6.0`       |
| `readerInvertImagesInDark` | `bool`      | `false`     |
| `readerOverrideFont`       | `bool`      | `true`      |
| `readerOverrideColor`      | `bool`      | `true`      |
| `readerUseBookLayout`      | `bool`      | `true`      |
| `readerBrightnessOverride` | `double?`   | `null`      |
| `onboardingCompleted`      | `bool`      | `false`     |
| `hasCompletedSetup`        | `bool`      | `false`     |

## Usage

```dart
// Create once in composition.dart
final preferencesService = await PreferencesService.create(
  supportedCodes: config.supportedLocaleCodes,
);

// Mount scope high in the tree
PreferencesScope(
  service: dependencies.preferencesService,
  child: MaterialContext(...),
)

// Read (rebuilds only when the relevant aspect changes)
final themeMode = PreferencesScope.themeModeOf(context);
final appearance = PreferencesScope.readerAppearanceOf(context);
final prefs = PreferencesScope.of(context); // rebuild on any change

// Update
await service.update((p) => p.copyWith(themeMode: ThemeMode.dark));
```

`update()` is non-fatal on disk errors: in-memory state still updates and
emits, so the UI stays consistent for the current session; the next launch
restores the last successfully-persisted value.

## Where it fits

Registered on `DependenciesContainer.preferencesService` in
`lib/app/composition.dart` and exposed via `PreferencesScope` in
`RootContext`. `MaterialContext` reads `themeModeOf(context)` to drive
`MaterialApp.themeMode`; the reader reads `readerAppearanceOf(context)`.
