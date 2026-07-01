part of 'import_flow_cubit.dart';

/// Sealed hierarchy describing every step the Add-to-Library sheet can
/// be in. The UI switches on the concrete type — each variant carries
/// exactly the fields its renderer needs.
sealed class ImportFlowState extends Equatable {
  const ImportFlowState();

  @override
  List<Object?> get props => const [];
}

/// Initial picker — single "Upload Book" entry.
class ImportFlowMenu extends ImportFlowState {
  const ImportFlowMenu();
}

class ImportFlowArticleUrlEntry extends ImportFlowState {
  const ImportFlowArticleUrlEntry({this.url = '', this.errorMessage});

  final String url;
  final String? errorMessage;

  String? get normalizedUrl => normalizeArticleUrl(url);
  bool get canSubmit => normalizedUrl != null;

  ImportFlowArticleUrlEntry copyWith({
    String? url,
    String? errorMessage,
  }) {
    return ImportFlowArticleUrlEntry(
      url: url ?? this.url,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [url, errorMessage];
}

class ImportFlowBookTermsRequired extends ImportFlowState {
  const ImportFlowBookTermsRequired();
}

/// Book file is being parsed and copied to disk.
///
/// `progress == null` means the byte-copy hasn't started yet — the
/// cubit shows an indeterminate spinner while metadata extraction
/// runs. The first progress callback from the repository switches the
/// bar to determinate.
class ImportFlowBookUploading extends ImportFlowState {
  const ImportFlowBookUploading({required this.filename, this.progress});

  final String filename;
  final double? progress;

  @override
  List<Object?> get props => [filename, progress];
}

/// Book import succeeded.
class ImportFlowBookDone extends ImportFlowState {
  const ImportFlowBookDone({
    required this.filename,
    required this.format,
    this.estimate,
  });

  final String filename;

  /// Format of the imported file. Lets the success view pick a
  /// noun-correct title (CBZ → "Comic added!", others → "Book added!")
  /// without the UI re-deriving it from the filename.
  final BookFormat format;

  /// "~5h estimated"-style read-time string. Hidden when null.
  final String? estimate;

  @override
  List<Object?> get props => [filename, format, estimate];
}

class ImportFlowArticleUploading extends ImportFlowState {
  const ImportFlowArticleUploading({
    required this.url,
    this.stage = ImportFlowArticleStage.fetching,
  });

  final String url;
  final ImportFlowArticleStage stage;

  @override
  List<Object?> get props => [url, stage];
}

class ImportFlowArticleDone extends ImportFlowState {
  const ImportFlowArticleDone({required this.title});

  final String title;

  @override
  List<Object?> get props => [title];
}

enum ImportFlowRetryTarget { book, article }

/// Terminal failure screen for the book path. Tap "Try again" re-opens
/// the file picker.
class ImportFlowFailure extends ImportFlowState {
  const ImportFlowFailure({
    required this.message,
    this.filename,
    this.retryTarget = ImportFlowRetryTarget.book,
  });

  final String message;

  /// Basename of the file the user picked, when known. Surfacing it on
  /// the failure screen mirrors the success view's filename line so the
  /// user can tell which item failed.
  final String? filename;
  final ImportFlowRetryTarget retryTarget;

  @override
  List<Object?> get props => [message, filename, retryTarget];
}
