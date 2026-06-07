import 'package:flutter_bloc/flutter_bloc.dart';

part 'library_selection_state.dart';

/// Tracks which library tiles are currently selected for bulk actions
/// (delete). Selection mode is implicit: the cubit is "active" iff at
/// least one id is selected. The first long-press on a tile starts
/// selection by toggling that id in.
class LibrarySelectionCubit extends Cubit<LibrarySelectionState> {
  LibrarySelectionCubit() : super(const LibrarySelectionState());

  void toggle(String id) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.add(id)) next.remove(id);
    emit(LibrarySelectionState(selectedIds: next));
  }

  void clear() {
    if (state.selectedIds.isEmpty) return;
    emit(const LibrarySelectionState());
  }
}
