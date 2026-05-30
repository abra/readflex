import 'package:domain_models/domain_models.dart';
import 'package:reader_webview/reader_webview.dart';

String readerTocEmptyMessage({
  required BookFormat? format,
  required bool hasSourceItems,
}) {
  if (hasSourceItems) return 'No matching chapters';

  return switch (format) {
    BookFormat.djvu => 'This DjVu file does not include a table of contents.',
    _ => 'No chapters found',
  };
}

String readerSearchPromptMessage(BookFormat? format) {
  return switch (format) {
    BookFormat.djvu =>
      'DjVu search uses the file OCR text layer. Type at least 2 characters to search.',
    _ => 'Type at least 2 characters to search',
  };
}

bool readerSearchActionEnabled({
  required BookFormat? format,
  required ReaderDocumentFeatures? documentFeatures,
}) {
  if (format != BookFormat.djvu) return true;
  return documentFeatures?.hasSearchableText == true;
}

String readerSearchActionTooltip({
  required BookFormat? format,
  required ReaderDocumentFeatures? documentFeatures,
}) {
  if (format != BookFormat.djvu) return 'Search';

  return switch (documentFeatures?.hasSearchableText) {
    true => 'Search',
    false => 'Search unavailable: no text layer',
    null => 'Checking DjVu text layer',
  };
}
