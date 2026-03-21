# monitoring

Package for logging, error reporting, and analytics.

Provides ready-to-use infrastructure (Logger, interfaces) and no-op stubs (Noop*)
that should be replaced with real implementations before shipping to production.

---

## What's included

| Class                      | Type                | Status                                                   |
|----------------------------|---------------------|----------------------------------------------------------|
| `Logger`                   | base class          | Ready — dispatches to attached `LogObserver`s            |
| `LogLevel`                 | enum                | Ready                                                    |
| `LogObserver`              | mixin               | Ready — implement to receive log messages                |
| `LogMessage`               | data class          | Ready                                                    |
| `PrintingLogObserver`      | concrete            | Ready — prints to console via `debugPrint`               |
| `ErrorReporterLogObserver` | concrete            | Ready — bridges Logger errors into ErrorReportingService |
| `ErrorReportingService`    | interface           | Implement for production                                 |
| `NoopErrorReporter`        | concrete            | Stub — does nothing, safe for development                |
| `AnalyticsEvent`           | abstract base class | Ready — extend to define typed events                    |
| `AnalyticsReporter`        | interface           | Implement for production                                 |
| `NoopAnalyticsReporter`    | concrete            | Stub — does nothing, safe for development                |

---

## Logger — how to add LogObservers

`Logger` uses the observer pattern: every call to `logger.info(...)` invokes
`onLog()` on all registered `LogObserver`s. You never modify `Logger` itself —
you just add or remove observers.

### Already configured in starter.dart

```dart

final logger = createAppLogger(
  observers: [
    ErrorReporterLogObserver(errorReporter), // errors go to ErrorReportingService
    if (!kReleaseMode)
      const PrintingLogObserver(logLevel: LogLevel.trace), // print to console
  ],
);
```

### How to write a custom LogObserver

```dart
// packages/monitoring/lib/src/file_log_observer.dart
final class FileLogObserver with LogObserver {
  @override
  void onLog(LogMessage logMessage) {
    File('app.log')
      .writeAsStringSync('${logMessage.timestamp} [${logMessage.level.toShortName()}] ${logMessage.message}\n',
      mode: FileMode.append,
    );
  }
}
```

### How to register it

```dart
// composition.dart — add to the observers list
observers: [
  ErrorReporterLogObserver(errorReporter),
  if (!kReleaseMode) const PrintingLogObserver(logLevel: LogLevel.trace),
  FileLogObserver(), // <- added
],
```

---

## ErrorReportingService — how to replace the stub

`NoopErrorReporter` is a stub: it accepts errors but does nothing with them.
For production, implement `ErrorReportingService`.

### Current (stub)

```dart
// composition.dart
Future<ErrorReportingService> createErrorReporter(ApplicationConfig config) async {
  const errorReporter = NoopErrorReporter(); // <- does nothing
  if (config.enableSentry) await errorReporter.initialize();
  return errorReporter;
}
```

### How to write a real implementation (example: Sentry)

```dart
// packages/monitoring/lib/src/sentry_error_reporter.dart
import 'package:sentry_flutter/sentry_flutter.dart';

final class SentryErrorReporter implements ErrorReportingService {
  @override
  bool get isInitialized => Sentry.isEnabled;

  @override
  Future<void> initialize() =>
      SentryFlutter.init((options) {
        options.dsn = 'your DSN from sentry.io';
      });

  @override
  Future<void> close() => Sentry.close();

  @override
  Future<void> captureException({
    required Object throwable,
    StackTrace? stackTrace,
  }) => Sentry.captureException(throwable, stackTrace: stackTrace);
}
```

### How to plug it in — change one line

```dart
// before:
const errorReporter = NoopErrorReporter();
// after:
final errorReporter = SentryErrorReporter();
```

Everything else (`DependenciesContainer`, BLoC, `starter.dart`) stays untouched —
they all depend on the `ErrorReportingService` interface, not a concrete class.

---

## AnalyticsReporter — how to use

`NoopAnalyticsReporter` is a stub: it accepts events but does not send them.
For production, implement `AnalyticsReporter`.

### 1. Add to DependenciesContainer

```dart
// dependency_container.dart
class DependenciesContainer {
  const DependenciesContainer({
    required this.logger,
    required this.errorReporter,
    required this.analyticsReporter, // <- add
    // ...
  });

  final AnalyticsReporter analyticsReporter;
// ...
}
```

### 2. Create in composition.dart

```dart
Future<DependenciesContainer> createDependenciesContainer(...) async {
  const analyticsReporter = NoopAnalyticsReporter(); // <- stub
  if (config.enableAnalytics) await analyticsReporter.initialize();

  return DependenciesContainer(analyticsReporter: analyticsReporter, // ...);
}
```

### 3. Define typed events in a feature package

```dart
// packages/features/notes/lib/src/analytics/notes_events.dart
import 'package:monitoring/monitoring.dart';

class NoteCreatedEvent extends AnalyticsEvent {
  const NoteCreatedEvent({required this.noteId});

  final String noteId;

  @override
  String get name => 'note_created';

  @override
  Map<String, Object?> get parameters => {'note_id': noteId};
}

class NoteDeletedEvent extends AnalyticsEvent {
  const NoteDeletedEvent({required this.noteId});

  final String noteId;

  @override
  String get name => 'note_deleted';

  @override
  Map<String, Object?> get parameters => {'note_id': noteId};
}
```

### 4. Use in BLoC

```dart
// notes_bloc.dart
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc({required this.analyticsReporter}) : super(NotesInitial()) {
    on<NoteCreated>(_onNoteCreated);
  }

  final AnalyticsReporter analyticsReporter;

  Future<void> _onNoteCreated(NoteCreated event, Emitter<NotesState> emit) async {
    // ... note creation logic ...
    await analyticsReporter.logEvent(NoteCreatedEvent(noteId: note.id));
  }
}
```

### How to write a real implementation (example: Firebase Analytics)

```dart
// packages/monitoring/lib/src/firebase_analytics_reporter.dart
import 'package:firebase_analytics/firebase_analytics.dart';

final class FirebaseAnalyticsReporter implements AnalyticsReporter {
  FirebaseAnalyticsReporter() : _analytics = FirebaseAnalytics.instance;
  final FirebaseAnalytics _analytics;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
    _initialized = true;
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> logEvent(AnalyticsEvent event) =>
      _analytics.logEvent(name: event.name, parameters: event.parameters);

  @override
  Future<void> setUserId(String? userId) => _analytics.setUserId(id: userId);
}
```

### How to plug it in — change one line

```dart
// before:
const analyticsReporter = NoopAnalyticsReporter();
// after:
final analyticsReporter = FirebaseAnalyticsReporter();
```

---

## Summary

```
Logger
  └── PrintingLogObserver       — already attached (console, debug/profile only)
  └── ErrorReporterLogObserver  — already attached (forwards errors to ErrorReporter)
  └── FileLogObserver           — write when needed
  └── SentryLogObserver         — write when needed

ErrorReportingService
  └── NoopErrorReporter         — current (stub)
  └── SentryErrorReporter       — replace when ready

AnalyticsReporter
  └── NoopAnalyticsReporter     — current (stub)
  └── FirebaseAnalyticsReporter — replace when ready
```
