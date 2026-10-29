import 'package:shared/shared.dart';

import 'reader_selection.dart';

/// Maps a selection's merge plan onto the text-action contract.
HighlightMergeTarget? highlightMergeTargetFor(ReaderHighlightMerge? merge) =>
    merge == null
    ? null
    : HighlightMergeTarget(
        cfiRange: merge.cfiRange,
        text: merge.text,
        highlightIds: merge.highlightIds,
      );
