import 'package:flutter/painting.dart';

const readerSelectionPreviewId = 'readflex-selection-preview';
const readerSearchHighlightId = 'readflex-search-mark';
const readerSearchActiveHighlightId = 'readflex-search-active';

/// Tints that are not saved highlights: taps on them fall through.
const readerTransientHighlightIds = {
  readerSelectionPreviewId,
  readerSearchHighlightId,
  readerSearchActiveHighlightId,
};

/// The active search hit's tint.
const readerSearchMarkColor = Color(0x66FFB300);
