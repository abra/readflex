import 'package:reader_webview/reader_webview.dart';
import 'package:shared/shared.dart';

/// Maps the WebView's merge plan onto the text-action contract.
HighlightMergeTarget? highlightMergeTargetFor(ReaderHighlightMerge? merge) =>
    merge == null
    ? null
    : HighlightMergeTarget(
        cfiRange: merge.cfiRange,
        text: merge.text,
        highlightIds: merge.highlightIds,
      );
