import 'package:flutter_bloc/flutter_bloc.dart';

part 'dictionary_selection_state.dart';

/// Tracks which dictionary rows are currently selected for bulk delete.
/// Selection mode is implicit: the cubit is "active" iff at least one
/// id is selected. The first long-press on a row starts selection by
/// toggling that id in.
class DictionarySelectionCubit extends Cubit<DictionarySelectionState> {
  DictionarySelectionCubit() : super(const DictionarySelectionState());

  void toggle(String id) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.add(id)) next.remove(id);
    emit(DictionarySelectionState(selectedIds: next));
  }

  void clear() {
    if (state.selectedIds.isEmpty) return;
    emit(const DictionarySelectionState());
  }
}
