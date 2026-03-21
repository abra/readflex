// Abstract interface for analytics reporting.
//
// Implement this class to integrate a real analytics service
// (e.g. Firebase Analytics, Amplitude, Mixpanel).
// Use NoopAnalyticsReporter during development or when analytics is disabled.

/// Base class for all analytics events.
///
/// Extend this to define typed events:
/// ```dart
/// class NoteCreatedEvent extends AnalyticsEvent {
///   const NoteCreatedEvent(this.noteId);
///   final String noteId;
///   @override
///   String get name => 'note_created';
///   @override
///   Map<String, Object?> get parameters => {'note_id': noteId};
/// }
/// ```
abstract base class AnalyticsEvent {
  const AnalyticsEvent();

  /// Event name sent to the analytics service (e.g. 'note_created').
  String get name;

  /// Optional key-value parameters attached to the event.
  Map<String, Object?> get parameters => const {};
}

/// Contract for analytics reporting services.
abstract interface class AnalyticsReporter {
  /// Whether the service has been initialized.
  bool get isInitialized;

  /// Initializes the analytics service.
  ///
  /// Call once during app startup before sending any events.
  Future<void> initialize();

  /// Releases resources held by the service.
  Future<void> close();

  /// Sends a typed [event] to the analytics service.
  Future<void> logEvent(AnalyticsEvent event);

  /// Associates all subsequent events with the given [userId].
  ///
  /// Call after sign-in. Pass null to clear the identity (on sign-out).
  Future<void> setUserId(String? userId);
}

/// No-op implementation of [AnalyticsReporter].
///
/// Does nothing — safe to use in development or when analytics
/// is not configured. Replace with a real implementation for production.
final class NoopAnalyticsReporter implements AnalyticsReporter {
  const NoopAnalyticsReporter();

  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> logEvent(AnalyticsEvent event) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}
