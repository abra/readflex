part of 'content_library_layout_cubit.dart';

enum ContentLibraryLayoutMode { list, grid }

extension ContentLibraryLayoutModeX on ContentLibraryLayoutMode {
  String get id => name;

  static ContentLibraryLayoutMode fromId(String? value) => switch (value) {
    'list' => ContentLibraryLayoutMode.list,
    _ => ContentLibraryLayoutMode.grid,
  };
}
