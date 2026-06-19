# preferences_service

User preferences: theme mode, locale, library layout, reader appearance,
per-source reader appearance overrides, reader search history, and onboarding /
setup flags. Backed by `shared_preferences` (JSON blob under a single key) and
exposed to the UI via a reactive stream and an `InheritedModel` scope.

This is **not** where credentials belong; production credentials should go
through a dedicated secure-storage backed service.

## Public API

| Symbol                          | Type             | Purpose                                                            |
|---------------------------------|------------------|--------------------------------------------------------------------|
| `Preferences`                   | data class       | Immutable snapshot of all preferences, with `copyWith`             |
| `ReaderAppearancePreferences`   | data class       | Global/effective reader appearance slice (theme, font, scale, etc.) |
| `ReaderAppearanceOverride`      | data class       | Optional per-source reader appearance override                    |
| `ReaderTextAlignment`           | enum             | Reader text alignment (`start`, `end`, `justify`)                 |
| `ReaderPageTurnStyle`           | enum             | Reader page-turn mode (`horizontal`, `vertical`)                  |
| `PreferencesService`            | concrete         | Loads, streams, and persists `Preferences`                         |
| `PreferencesStorage`            | concrete         | Thin `SharedPreferences` wrapper                                   |
| `PreferencesRepository`         | concrete         | JSON (de)serialization + locale resolution                         |
| `PreferencesScope`              | StatelessWidget  | `InheritedModel` with `themeMode` / `readerAppearance` aspects     |

### What is stored

| Field                      | Type        | Default     |
|----------------------------|-------------|-------------|
| `themeMode`                | `ThemeMode` | `system`    |
| `locale`                   | `Locale`    | platform    |
| `libraryLayoutMode`        | `String`    | `'grid'`    |
| `readerThemeId`            | `String`    | `'paper'`   |
| `readerFontId`             | `String`    | `'serif'`   |
| `readerLayoutId`           | `String`    | `'standard'`|
| `readerTextScale`          | `double`    | `1.0`       |
| `readerLineHeight`         | `double`    | `1.55`      |
| `readerSideMargin`         | `double`    | `8.0`       |
| `readerTextAlignment`      | `ReaderTextAlignment` | `start` |
| `readerInvertImagesInDark` | `bool`      | `false`     |
| `readerOverrideFont`       | `bool`      | `true`      |
| `readerOverrideColor`      | `bool`      | `true`      |
| `readerUseBookLayout`      | `bool`      | `true`      |
| `readerPageTurnStyle`      | `ReaderPageTurnStyle` | `horizontal` |
| `readerBrightness`         | `double?`   | `null`      |
| `readerLastCustomBrightness` | `double`  | `0.7`       |
| `readerSearchHistory`      | `List<String>` | `[]`     |
| `readerAppearanceOverrides`| `Map<String, ReaderAppearanceOverride>` | `{}` |
| `bookImportTermsAcceptedVersion` | `int`  | `0`         |
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

// Reader-specific override for one source/book.
await service.setReaderAppearanceOverride(
  sourceId,
  const ReaderAppearanceOverride(fontId: 'ptSerif'),
);
```

`update()` is non-fatal on disk errors: in-memory state still updates and
emits, so the UI stays consistent for the current session; the next launch
restores the last successfully-persisted value.

## Where it fits

Registered on `DependenciesContainer.preferencesService` in
`lib/app/composition.dart` and exposed via `PreferencesScope` in
`RootContext`. `MaterialContext` reads `themeModeOf(context)` to drive
`MaterialApp.themeMode`; the reader applies per-source overrides through
`ReaderAppearanceCubit`.
