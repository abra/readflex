import 'comic_highlights_test.dart' as comics;
import 'library_controls_test.dart' as library_controls;
import 'reader_note_sheet_test.dart' as notes;
import 'toast_test.dart' as toasts;

/// Shared-controls regression batch. Services use the existing isolated fixtures.
void main() {
  library_controls.main();
  comics.main();
  notes.main();
  toasts.main();
}
