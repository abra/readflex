import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

/// Transient UI state for a tapped saved highlight.
///
/// The saved highlight list itself stays in [ReaderBloc]. This cubit only
/// remembers which highlight should show the floating edit/delete popup.
class ReaderHighlightFocusState extends Equatable {
  const ReaderHighlightFocusState({
    this.highlightId,
    this.position,
    this.contextText,
  });

  final String? highlightId;
  final ReaderSelectionPosition? position;
  final String? contextText;

  bool get hasHighlight => highlightId != null && highlightId!.isNotEmpty;

  @override
  List<Object?> get props => [highlightId, position, contextText];
}

class ReaderHighlightFocusCubit extends Cubit<ReaderHighlightFocusState> {
  ReaderHighlightFocusCubit() : super(const ReaderHighlightFocusState());

  void focus(ReaderHighlightTap tap) {
    emit(
      ReaderHighlightFocusState(
        highlightId: tap.highlightId,
        position: tap.position,
        contextText: tap.contextText,
      ),
    );
  }

  void clear() => emit(const ReaderHighlightFocusState());
}
