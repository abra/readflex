# monitoring

Logging, GlitchTip error reporting, and optional analytics contracts.

## Public API

| Symbol | Responsibility |
|--------|----------------|
| `Logger`, `LogLevel`, `LogMessage` | Dispatch structured messages to registered observers |
| `LogObserver` | Observer contract for log consumers |
| `PrintingLogObserver` | Console output filtered by level |
| `ErrorReporterLogObserver` | Forwards error/fatal messages to an error reporter |
| `ErrorReportingService` | Error reporting lifecycle and capture contract |
| `GlitchTipErrorReporter` | Sentry-compatible Dart SDK adapter |
| `NoopErrorReporter` | No-op when reporting is not configured |
| `AnalyticsEvent`, `AnalyticsReporter` | Optional typed analytics contracts |
| `NoopAnalyticsReporter` | No-op implementation, not wired into app composition |

## App Wiring

`lib/app/starter.dart` creates the logger before entering the startup error
zone. It attaches `PrintingLogObserver` only outside release mode.
Flutter, platform-dispatcher, zone and BLoC errors use that logger.

`AppBootstrap` validates configuration, calls `createErrorReporter` from
`composition.dart`, and attaches `ErrorReporterLogObserver` once after the
factory succeeds. That factory initializes `GlitchTipErrorReporter` when a DSN
exists, or returns `NoopErrorReporter` otherwise. Reporting and logging survive
failed dependency/reader preparation attempts so Retry can reuse them; the
running application's resource disposer closes them on final disposal.
Failures before the observer is attached cannot be sent through it.

`AppBlocObserver` skips event/transition formatting in release but still
reports errors. This does not suppress unrelated direct `debugPrint` calls in
other packages.

To add an observer, use `logger.addObserver(observer)` at the owning composition
boundary. `Logger` calls observers synchronously; avoid blocking disk/network
work in `onLog`. `Logger.destroy()` clears observers, but does not close custom
observer resources. Register any such cleanup with its owner explicitly.

## Error Reporting

The package uses `sentry`, not `sentry_flutter`. The application wires Flutter
error handlers itself; automatic native crash capture and Flutter performance
instrumentation from `sentry_flutter` are not part of this integration.

| Compile-time flag | Behavior |
|-------------------|----------|
| `GLITCHTIP_DSN` | Preferred DSN; empty values fall back to `SENTRY_DSN` |
| `SENTRY_DSN` | Compatibility fallback |
| `GLITCHTIP_TRACES_SAMPLE_RATE` | Trace sampling rate, default `0`; the adapter clamps it to `0..1` and maps NaN to `0` |

A sample rate controls transactions that are actually created. Setting it
does not instrument reader actions or HTTP requests: the app currently does not
create Sentry transactions. It does not sample error events.

The adapter explicitly disables default PII collection; other SDK defaults
are not overridden here. Initialization failure is deliberately non-fatal:
the reporter remains uninitialized and capture becomes a no-op. The observer
forwards captures without awaiting their futures and does not add its own
capture-failure handling. Successful initialization is not proof that the
server has accepted a particular event.

## Analytics

Analytics contracts are available for future use, but `DependenciesContainer`
has no analytics field and the current composition creates no analytics
provider. Do not describe analytics as an active product flow. Adding a real
provider requires explicit composition, lifecycle cleanup, privacy decisions,
and tests, not just replacing a class name in this package.

## Verification

Run `fvm flutter test` from this package for logger, observer, and error-reporter
contracts using fake clients. Root bootstrap tests separately cover observer
attachment, retries and resource ownership. These tests do not send events to
a live GlitchTip instance.
