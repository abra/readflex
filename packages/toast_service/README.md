# toast_service

Thin app wrapper around `toastification` for top-anchored feedback messages.

## Public API

| Symbol | Kind | Purpose |
|--------|------|---------|
| `ToastWrapper` | widget | Mounts the overlay/config wrapper once around the app shell |
| `showToast(...)` | function | Shows a success or error toast |
| `NotificationType` | enum | Type-safe toast style selector |

## Usage

Mount `ToastWrapper` once near the app root so feature code can show toasts
against the active overlay:

```dart
ToastWrapper(child: AppView(...))
```

Feature packages should call:

```dart
showToast(
  context,
  type: NotificationType.success,
  message: title,
  messageSuffix: ' deleted',
);
```

Use `messageSuffix` when the verb/tail must remain visible while a long title
ellipsises. It wraps to another line if it cannot fit beside the title; a long
localized suffix wraps within the available width rather than overflowing.

## Design Contract

Toasts are aligned with the app's horizontal body padding, capped on large
screens, and slide down from the status bar. Features should not import
`toastification` directly; keeping this wrapper small makes it easy to change
toast libraries later.

`showCustom` uses a package-private layout with the shared `AppPlainIconButton`,
Lucide status icons, `bodyMedium`, radius and shadow tokens. The library's built-in
Close slot is limited to 30dp; replacing only its icon cannot provide our 48dp
target. The visible 20dp Close glyph aligns with the toast's 16dp inner gutter.
Its tooltip uses the current Material localization, and the full message is a
separate live-region semantics node, including visually ellipsized text.

Success uses the paired `successContainer` / `onSuccessContainer` app colors;
errors use `ColorScheme.error` / `onError`. Neither inherits the dependency's
independent palette or low-opacity Close icon.

The overlay applies the 16dp horizontal margin once, adds system/keyboard insets,
and constrains the 520dp width cap on narrower screens. There is no minimum width
that can overrun a compact viewport, or cached screen-width calculation that
becomes stale after rotation.

Success toasts keep the agreed 1-second duration. Errors remain for 6 seconds;
with `MediaQuery.accessibleNavigation` they require explicit dismissal. Reduced
motion skips the slide transition. Toasts do not replace inline form errors or
retry actions, and bookmark Undo remains an icon on the affected row.
Reduced motion also disables the list's entry/exit size animation. The library
continues to own timers, stacking, hover pause and swipe dismissal. Each show
requests a frame for its deferred insertion, including when an existing overlay
is idle; no polling, new timer or recurring animation is added.

## Verification

`test/toast_service_test.dart` covers durations and accessible persistent errors.
`test/toast_layout_test.dart` covers 48dp targets/corners, circular feedback,
semantics, RTL, large text, narrow screens, rotation/safe areas, idle insertion
and independent swipe dismissal. These tests run in `make test-ui-contracts`.
Root `test/ui/toast_golden_test.dart` captures the production Library underneath
both notification types, including an Arabic phone, dark mode and 200% text.
`integration_test/toast_test.dart` checks native phone layout, localized Close,
swipe dismissal and success expiry with isolated app fixtures; it is also part
of `integration_test/ui_consistency_test.dart`.

## Dependencies

- `component_library` - spacing, radius, and design tokens
- `toastification`
- `flutter`
