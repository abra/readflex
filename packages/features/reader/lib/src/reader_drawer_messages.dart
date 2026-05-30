import 'package:domain_models/domain_models.dart';
import 'package:reader_webview/reader_webview.dart';

String readerTocEmptyMessage({
  required BookFormat? format,
  required bool hasSourceItems,
}) {
  if (hasSourceItems) return 'No matching chapters';
  return 'No chapters found';
}

String readerSearchPromptMessage(BookFormat? format) {
  return 'Type at least 2 characters to search';
}

bool readerSearchActionEnabled({
  required BookFormat? format,
  required ReaderDocumentFeatures? documentFeatures,
}) {
  return true;
}

String readerSearchActionTooltip({
  required BookFormat? format,
  required ReaderDocumentFeatures? documentFeatures,
}) {
  return 'Search';
}
