part of 'library_layout_cubit.dart';

enum LibraryLayoutMode { list, grid }

extension LibraryLayoutModeX on LibraryLayoutMode {
  String get id => name;

  static LibraryLayoutMode fromId(String? value) => switch (value) {
    'list' => LibraryLayoutMode.list,
    _ => LibraryLayoutMode.grid,
  };
}
