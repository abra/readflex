import 'package:domain_models/domain_models.dart';

import 'reader_format_capabilities.dart';

export 'reader_format_capabilities.dart' show ReaderChromeAction;

Set<ReaderChromeAction> readerChromeActionsForFormat(BookFormat? format) =>
    readerFormatCapabilitiesFor(format: format).chromeActions;

Set<ReaderChromeAction> readerChromeActionsFor({
  required SourceType sourceType,
  required BookFormat? format,
}) => readerFormatCapabilitiesFor(
  sourceType: sourceType,
  format: format,
).chromeActions;
