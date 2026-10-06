import 'dart:ui' show Color;

import 'package:domain_models/domain_models.dart';

/// Maps a [HighlightColor] to the swatch the sheet paints.
///
/// `showHighlightSheet` defaults to the app palette (`AppColorsExt`); a reader
/// caller passes its reader-theme palette so the preview and swatches match
/// the page the highlight will be drawn on.
typedef HighlightColorResolver = Color Function(HighlightColor color);
