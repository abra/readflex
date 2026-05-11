# connectivity_service

Reactive network connectivity monitor. The app shell subscribes to the stream
to show the offline banner. Treat the status as a UX signal only: a visible
network interface does not guarantee that a backend request will succeed.

Production composition wires `ConnectivityPlusService.create()`, backed by
`connectivity_plus`. `NoopConnectivityService` remains available for tests and
isolated development surfaces.

## Public API

| Symbol                      | Type           | Purpose                            |
|-----------------------------|----------------|------------------------------------|
| `ConnectivityService`       | abstract class | Contract: status + reactive stream |
| `ConnectivityPlusService`   | concrete       | Production adapter over `connectivity_plus` |
| `NoopConnectivityService`   | concrete       | Stub — always `online`             |
| `ConnectivityStatus`        | enum           | `online` / `offline`               |

### Methods

- `ConnectivityStatus get status` — latest known status.
- `Stream<ConnectivityStatus> get statusStream` — emits on every change.
- `void dispose()` — releases platform listeners.

## Usage

```dart
ConnectivityScope.of(context) == ConnectivityStatus.offline
    ? const OfflineBanner()
    : const SizedBox.shrink();
```

## Where it fits

Registered on `DependenciesContainer.connectivityService` in
`lib/app/composition.dart`, then mounted by `ConnectivityScope` around the app
shell. Feature UI should consume `ConnectivityScope`; lower-level services
should still attempt their work and handle request failures directly.
