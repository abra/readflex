# onboarding

The welcome screen shown on the first app launch: the app icon above "Welcome
to Readflex", four feature rows of equal weight and two actions, Add your first
book and Not now.

## Public API

```dart
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required VoidCallback onAddBook,
    required VoidCallback onNotNow,
  });
}
```

The screen has no Bloc/Cubit and keeps no state. Both actions finish
onboarding; `routing.dart` owns what happens next. It saves
`onboardingCompleted` in preferences and goes to Library. Add your first book
also opens file import there once (`LibraryRouteArguments.openImportOnStart`).
The `/onboarding` redirect for a first launch lives in the router as well.

## Layout

- The heading shrinks, down to 60% of its role size, only when a single word
  is wider than the line, so it never breaks mid-word. Chinese and Japanese
  break between characters and never shrink.
- The feature list names the reader's real selection menu labels (Translate,
  Define) so the copy matches the buttons the reader will see.
- Content and actions stop at 480dp, so tablets keep the phone's single
  column. At large text the content scrolls and the actions stay below it.
- Nothing animates.

Selecting text is taught in the reader by its one-time tip, not here.

## Assets

`assets/app_icon.png` (80px, with `2.0x/` and `3.0x/` variants) is declared in
this package's `pubspec.yaml`. The app loads it as
`packages/onboarding/assets/app_icon.png` via `AssetImage(package:
'onboarding')`; the app's own `pubspec.yaml` does not list it. The icon is
decorative and hidden from screen readers.

## Tests

- `test/` covers the package contract: each action calls only its callback,
  and the icon is bundled at 1x, 2x and 3x and resolved from this package.
- The app's `test/ui/onboarding_test.dart` covers layout, copy, accessibility,
  large text in every locale, RTL and goldens.
- `test/app/readflex_app_test.dart` covers the redirect and saved completion.

## Dependencies

- `component_library` — theme tokens, icons, `AppButtonLabel`
- `readflex_localizations` — copy
