part of 'catalog_layout_cubit.dart';

enum CatalogLayoutMode { list, grid }

extension CatalogLayoutModeX on CatalogLayoutMode {
  String get id => name;

  static CatalogLayoutMode fromId(String? value) => switch (value) {
    'list' => CatalogLayoutMode.list,
    _ => CatalogLayoutMode.grid,
  };
}
