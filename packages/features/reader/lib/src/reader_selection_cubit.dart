import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Current in-WebView text selection, mirrored into Flutter so the context
/// panel can drive its show/hide animation and pass position metadata to
/// TextAction handlers. [contextText] carries surrounding text for
/// contextual translation. [cfiRange] is populated whenever [hasSelection] is
/// true; [pageNumber] and [scrollOffset] are legacy optional position fields.
class ReaderSelectionState extends Equatable {
  const ReaderSelectionState({
    this.selectedText = '',
    this.normalizedSelectedText,
    this.selectionKind,
    this.contextText,
    this.markedContextText,
    this.normalizedMarkedContextText,
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
    this.hasSelection = false,
  });

  final String selectedText;

  /// Selection expanded to complete word boundaries for lexical actions.
  final String? normalizedSelectedText;

  /// Reader-side selection shape, e.g. exact, partial_word, partial_span.
  final String? selectionKind;

  /// Surrounding sentence/paragraph excerpt for context-aware actions.
  final String? contextText;

  /// Same excerpt with the exact selected range wrapped in [[...]].
  final String? markedContextText;

  /// Same excerpt with the normalized lexical range wrapped in [[...]].
  final String? normalizedMarkedContextText;

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
    Object? normalizedSelectedText = _absent,
    Object? selectionKind = _absent,
    Object? contextText = _absent,
    Object? markedContextText = _absent,
    Object? normalizedMarkedContextText = _absent,
    Object? cfiRange = _absent,
    Object? pageNumber = _absent,
    Object? scrollOffset = _absent,
    bool? hasSelection,
  }) => ReaderSelectionState(
    selectedText: selectedText ?? this.selectedText,
    normalizedSelectedText: normalizedSelectedText == _absent
        ? this.normalizedSelectedText
        : normalizedSelectedText as String?,
    selectionKind: selectionKind == _absent
        ? this.selectionKind
        : selectionKind as String?,
    contextText: contextText == _absent
        ? this.contextText
        : contextText as String?,
    markedContextText: markedContextText == _absent
        ? this.markedContextText
        : markedContextText as String?,
    normalizedMarkedContextText: normalizedMarkedContextText == _absent
        ? this.normalizedMarkedContextText
        : normalizedMarkedContextText as String?,
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
    normalizedSelectedText,
    selectionKind,
    contextText,
    markedContextText,
    normalizedMarkedContextText,
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
    String? normalizedText,
    String? selectionKind,
    String? contextText,
    String? markedContextText,
    String? normalizedMarkedContextText,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
  }) {
    emit(
      ReaderSelectionState(
        selectedText: text,
        normalizedSelectedText: normalizedText,
        selectionKind: selectionKind,
        contextText: contextText,
        markedContextText: markedContextText,
        normalizedMarkedContextText: normalizedMarkedContextText,
        cfiRange: cfiRange,
        pageNumber: pageNumber,
        scrollOffset: scrollOffset,
        hasSelection: true,
      ),
    );
  }

  void deselect() => emit(const ReaderSelectionState());
}
