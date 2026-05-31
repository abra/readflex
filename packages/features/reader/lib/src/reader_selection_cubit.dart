import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Current in-WebView text selection, mirrored into Flutter so the context
/// panel can drive its show/hide animation and pass position metadata to
/// TextAction handlers. [cfiRange] is populated whenever [hasSelection] is
/// true; [pageNumber] and [scrollOffset] are legacy optional position fields.
class ReaderSelectionState extends Equatable {
  const ReaderSelectionState({
    this.selectedText = '',
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
    this.hasSelection = false,
  });

  final String selectedText;

  /// CFI range of the selected text.
  final String? cfiRange;

  /// Legacy optional page position.
  final int? pageNumber;

  /// Legacy optional scroll position.
  final double? scrollOffset;

  final bool hasSelection;

  static const _absent = Object();

  ReaderSelectionState copyWith({
    String? selectedText,
    Object? cfiRange = _absent,
    Object? pageNumber = _absent,
    Object? scrollOffset = _absent,
    bool? hasSelection,
  }) => ReaderSelectionState(
    selectedText: selectedText ?? this.selectedText,
    cfiRange: cfiRange == _absent ? this.cfiRange : cfiRange as String?,
    pageNumber: pageNumber == _absent ? this.pageNumber : pageNumber as int?,
    scrollOffset: scrollOffset == _absent
        ? this.scrollOffset
        : scrollOffset as double?,
    hasSelection: hasSelection ?? this.hasSelection,
  );

  @override
  List<Object?> get props => [
    selectedText,
    cfiRange,
    pageNumber,
    scrollOffset,
    hasSelection,
  ];
}

/// Mirrors WebView text-selection events into Flutter state so the
/// [_ContextPanel] can appear/disappear and TextActions can access the
/// selected text + location metadata.
class ReaderSelectionCubit extends Cubit<ReaderSelectionState> {
  ReaderSelectionCubit() : super(const ReaderSelectionState());

  void select({
    required String text,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
  }) {
    emit(
      ReaderSelectionState(
        selectedText: text,
        cfiRange: cfiRange,
        pageNumber: pageNumber,
        scrollOffset: scrollOffset,
        hasSelection: true,
      ),
    );
  }

  void deselect() => emit(const ReaderSelectionState());
}
