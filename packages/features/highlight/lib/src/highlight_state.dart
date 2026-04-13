part of 'highlight_cubit.dart';

enum HighlightSheetStatus { idle, saving, success, failure }

class HighlightSheetState extends Equatable {
  const HighlightSheetState({
    this.status = HighlightSheetStatus.idle,
    this.selectedColor = HighlightColor.yellow,
    this.note = '',
  });

  final HighlightSheetStatus status;
  final HighlightColor selectedColor;
  final String note;

  HighlightSheetState copyWith({
    HighlightSheetStatus? status,
    HighlightColor? selectedColor,
    String? note,
  }) => HighlightSheetState(
    status: status ?? this.status,
    selectedColor: selectedColor ?? this.selectedColor,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => [status, selectedColor, note];
}
