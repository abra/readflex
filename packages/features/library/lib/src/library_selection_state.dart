part of 'library_selection_cubit.dart';

class LibrarySelectionState {
  const LibrarySelectionState({this.selectedIds = const <String>{}});

  final Set<String> selectedIds;

  bool get isActive => selectedIds.isNotEmpty;

  int get count => selectedIds.length;

  bool contains(String id) => selectedIds.contains(id);

  @override
  bool operator ==(Object other) =>
      other is LibrarySelectionState &&
      other.selectedIds.length == selectedIds.length &&
      other.selectedIds.containsAll(selectedIds);

  @override
  int get hashCode => Object.hashAllUnordered(selectedIds);
}
