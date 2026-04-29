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
  const ImportFlowBookDone({required this.filename, this.estimate});

  final String filename;

  /// "~5h estimated"-style read-time string. Hidden when null.
  final String? estimate;

  @override
  List<Object?> get props => [filename, estimate];
}

/// Terminal failure screen for the book path. Tap "Try again" returns
/// to the menu via [ImportFlowCubit.backToMenu].
class ImportFlowFailure extends ImportFlowState {
  const ImportFlowFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
