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
ellipsises.

## Design Contract

Toasts are aligned with the app's horizontal body padding, capped on large
screens, and slide down from the status bar. Features should not import
`toastification` directly; keeping this wrapper small makes it easy to change
toast libraries later.

## Dependencies

- `component_library` - spacing, radius, and design tokens
- `toastification`
- `flutter`
