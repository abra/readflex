import 'package:component_library/component_library.dart';
import 'package:flutter/painting.dart';

/// Emphasis of chrome text drawn straight on the page. 78% of the page text
/// over the page keeps at least 4.5:1 on every reader preset; Graphite is the
/// lowest at about 4.8:1.
const _readerChromeInkEmphasis = 0.78;

const _readerChromeTrackEmphasis = 0.2;

/// Opaque muted foreground for the top line and persistent article progress,
/// drawn directly on the reading page.
Color readerChromeInkColor(ReaderThemeData theme) => Color.alphaBlend(
  theme.primaryTextColor.withValues(alpha: _readerChromeInkEmphasis),
  theme.backgroundColor,
);

/// Unfilled part of the progress track on the page.
Color readerChromeTrackColor(ReaderThemeData theme) => Color.alphaBlend(
  theme.primaryTextColor.withValues(alpha: _readerChromeTrackEmphasis),
  theme.backgroundColor,
);
