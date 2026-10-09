# toast_service

Thin app wrapper around `toastification` for bottom-anchored feedback messages
that float above the screen's bottom controls.

## Public API

| Symbol | Kind | Purpose |
|--------|------|---------|
| `ToastWrapper` | widget | Mounts the overlay/config wrapper once around the app shell |
| `showToast(...)` | function | Shows a success or error toast |
| `NotificationType` | enum | Type-safe toast style selector |
| `ToastAvoidArea` | widget | Marks a bottom control that toasts must float above |
| `ToastNavigatorObserver` | navigator observer | Dismisses toasts when a sheet or dialog opens |
| `toastSuccessDuration` / `toastErrorDuration` | constants | How long each type stays |

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

Wrap bottom controls that a toast must not cover, such as a floating capsule,
a selection bar or a reader toolbar, and pass `enabled: false` while a mounted
control is hidden:

```dart
ToastAvoidArea(enabled: chromeVisible, child: bottomChrome)
```

Use `messageSuffix` when the verb/tail must remain visible while a long title
ellipsises. It wraps to another line if it cannot fit beside the title; a long
localized suffix wraps within the available width rather than overflowing.

## Design Contract

Toasts are aligned with the app's horizontal body padding, capped on large
screens, and slide up from the bottom edge, where the thumb already is. They
sit 16dp above the bottom safe inset, or 8dp above the highest
`ToastAvoidArea` on screen when that is higher, so the Library capsule and the
reader's bottom chrome stay visible and tappable. Features should not import
`toastification` directly; keeping this wrapper small makes it easy to change
toast libraries later.

`showCustom` uses a package-private layout with the shared `AppPlainIconButton`,
Lucide status icons, `bodyMedium`, radius and shadow tokens. The library's built-in
Close slot is limited to 30dp; replacing only its icon cannot provide our 48dp
target. The visible 20dp Close glyph aligns with the toast's 16dp inner gutter.
Its tooltip uses the current Material localization, and the full message is a
separate live-region semantics node, including visually ellipsized text.

Both types use one neutral plate, `ColorScheme.inverseSurface` /
`onInverseSurface` (dark in the light theme, light in the dark theme), so a
confirmation does not flash a saturated banner over the page; only the status
glyph is colored, with `AppColorsExt.successOnInverse` / `errorOnInverse`.
Neither inherits the dependency's independent palette or low-opacity Close
icon.

### Placement

`showToast` measures every mounted, enabled `ToastAvoidArea` once, when the
toast appears, and keeps the lowest toast `toastAvoidGap` above the highest one
whose top is in the lower half of the view. Positions come from layout
offsets, not paint transforms, so a control that is still scaling or sliding
in (the Library capsule after selection ends) counts where it comes to rest.
Areas on a route covered by an opaque route are skipped: those routes stay
mounted offstage with their tickers muted.

The lift moves the whole toast overlay through its margin, not padding inside
each toast: the overlay's scrollable list hit-tests its full extent, so padding
would leave an invisible tap-blocking band over the very controls it avoids.
The margin builder runs in the Navigator's overlay, below `ToastWrapper`, and
reads the lift from `ToastLiftScope`, an `InheritedNotifier`, so a new lift
re-lays out the overlay. The latest toast decides the lift for the stack; a
control that appears or moves while a toast is visible does not move it.

A sheet or dialog that opens later would have its commands under a toast still
showing (a 6-second error, then a retry's confirmation). `ToastNavigatorObserver`,
registered on the router's root navigator where sheets and dialogs open,
dismisses visible toasts on every `PopupRoute` push: they describe the screen
the user has moved on from. Page routes keep them. A toast shown while a sheet
is open sits over the sheet's lower content until it expires or is swiped.

The overlay applies the 16dp horizontal margin once, adds system/keyboard insets,
and constrains the 520dp width cap on narrower screens. There is no minimum width
that can overrun a compact viewport, or cached screen-width calculation that
becomes stale after rotation.

Success toasts stay 4 seconds (`toastSuccessDuration`, as a Material snackbar),
long enough to read a book title; the earlier 1 second was too short for that.
Errors remain for 6 seconds;
with `MediaQuery.accessibleNavigation` they require explicit dismissal. Reduced
motion skips the slide transition. Toasts do not replace inline form errors or
retry actions, and bookmark Undo remains an icon on the affected row.
Reduced motion also disables the list's entry/exit size animation. The library
continues to own timers, stacking, hover pause and swipe dismissal. Each show
requests a frame for its deferred insertion, including when an existing overlay
is idle; no polling, new timer or recurring animation is added.

## Verification

`test/toast_service_test.dart` covers durations and accessible persistent errors.
`test/toast_placement_test.dart` covers the bottom margin over the safe inset,
floating above a marked control (with and without an inset), taps on that
control under the toast stack, a control mid-way through an entrance scale,
hidden areas, areas in the upper half and on covered routes, sheet pushes that
dismiss and page pushes that keep a toast, and the neutral plate's text and
glyph contrast in both themes.
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
