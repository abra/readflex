/// Which import step the Library asks the import UI to open.
enum LibraryImportEntry {
  /// The import menu (file or article), from the header "+".
  menu,

  /// Straight to the device file picker.
  file,

  /// Straight to the article link form.
  article,
}
