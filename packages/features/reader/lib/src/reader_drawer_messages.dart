import 'package:domain_models/domain_models.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_document_features.dart';

String readerTocEmptyMessage({
  required ReadflexLocalizations l10n,
  required BookFormat? format,
  required bool hasSourceItems,
}) {
  if (hasSourceItems) return l10n.readerNoMatchingChapters;
  return l10n.readerNoChaptersFound;
}

String readerSearchPromptMessage(
  ReadflexLocalizations l10n,
  BookFormat? format,
) {
  return l10n.readerSearchPrompt;
}

bool readerSearchActionEnabled({
  required BookFormat? format,
  required ReaderDocumentFeatures? documentFeatures,
}) {
  // Search discovers text lazily; static action visibility belongs to the
  // format policy, not to the first page's optional text-layer report.
  return true;
}

String readerSearchActionTooltip({
  required ReadflexLocalizations l10n,
  required BookFormat? format,
  required ReaderDocumentFeatures? documentFeatures,
}) {
  return l10n.readerSearchAction;
}
