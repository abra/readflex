/// What makes vellum hand a reflowable book to another reader: books it
/// cannot lay out yet, so the host can open them the way it did before.
library;

import '../vellum_exception.dart';

/// Why a book is not vellum's to lay out.
enum TextBookUnsupported {
  /// Pages of a fixed size (`rendition:layout` `pre-paginated`, KF8's
  /// fixed layout): foliate-js's fixed-layout renderer, not reflow.
  fixedLayout,

  /// Vertical lines (`writing-mode: vertical-rl` on the body): vellum
  /// lays out horizontal lines only.
  verticalWriting,
}

/// Raised by `TextPagesController` (as its `error`) when the book, or a
/// section turned to, needs what vellum does not lay out.
class UnsupportedTextBookException extends VellumException {
  const UnsupportedTextBookException(this.reason)
    : super('Not laid out by vellum');

  final TextBookUnsupported reason;

  @override
  String toString() => 'UnsupportedTextBookException: ${reason.name}';
}
