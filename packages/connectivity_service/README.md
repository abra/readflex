# connectivity_service

Reactive network connectivity monitor. Features subscribe to the stream to
show an offline banner, and services use the current status to pick between
remote and local code paths (e.g. translation fallback).

The production implementation wraps `connectivity_plus`; in development the
wiring uses `NoopConnectivityService` (always online).

## Public API

| Symbol                      | Type           | Purpose                            |
|-----------------------------|----------------|------------------------------------|
| `ConnectivityService`       | abstract class | Contract: status + reactive stream |
| `NoopConnectivityService`   | concrete       | Stub — always `online`             |
| `ConnectivityStatus`        | enum           | `online` / `offline`               |

### Methods

- `ConnectivityStatus get status` — latest known status.
- `Stream<ConnectivityStatus> get statusStream` — emits on every change.
- `void dispose()` — releases platform listeners.

## Usage

```dart
final connectivity = context.dependencies.connectivityService;

// One-shot check inside a service
if (connectivity.status == ConnectivityStatus.offline) {
  return _fallbackLocally();
}

// Reactive banner
StreamBuilder<ConnectivityStatus>(
  stream: connectivity.statusStream,
  initialData: connectivity.status,
  builder: (context, snap) => snap.data == ConnectivityStatus.offline
      ? const OfflineBanner()
      : const SizedBox.shrink(),
);
```

## Where it fits

Registered on `DependenciesContainer.connectivityService` in
`lib/app/composition.dart`. Passed to the container via DI — no
`InheritedWidget` scope, per project rules (see CLAUDE.md "Cross-Cutting
Concerns"). Swap `NoopConnectivityService` for a `connectivity_plus`-backed
implementation when ready.
