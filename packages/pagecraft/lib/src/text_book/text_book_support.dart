/// What makes pagecraft hand a reflowable book to another reader: books it
/// cannot lay out yet, so the host can open them the way it did before.
library;

import '../pagecraft_exception.dart';

/// Why a book is not pagecraft's to lay out.
enum TextBookUnsupported {
  /// Pages of a fixed size (`rendition:layout` `pre-paginated`, KF8's
  /// fixed layout): foliate-js's fixed-layout renderer, not reflow.
  fixedLayout,

  /// Vertical lines (`writing-mode: vertical-rl` on the body): pagecraft
  /// lays out horizontal lines only.
  verticalWriting,
}

/// Raised by `TextPagesController` (as its `error`) when the book, or a
/// section turned to, needs what pagecraft does not lay out.
class UnsupportedTextBookException extends PagecraftException {
  const UnsupportedTextBookException(this.reason)
    : super('Not laid out by pagecraft');

  final TextBookUnsupported reason;

  @override
  String toString() => 'UnsupportedTextBookException: ${reason.name}';
}
