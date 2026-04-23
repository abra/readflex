import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';

/// Registers the three JS → Flutter bridge handlers that are identical
/// for both reader WebViews — `onSelectionEnd`, `onSelectionCleared`,
/// `onClick` — and wires each one to the provided Dart callback.
///
/// Extracted so [BookReaderWebView] and [ArticleReaderWebView] don't
/// duplicate the same glue code.
void registerSharedReaderHandlers(
  InAppWebViewController controller, {
  void Function(ReaderSelection)? onTextSelected,
  VoidCallback? onTextDeselected,
  void Function(double x, double y)? onTapped,
}) {
  controller.addJavaScriptHandler(
    handlerName: 'onSelectionEnd',
    callback: (args) {
      if (args.isEmpty) return;
      final data = args.first as Map<String, dynamic>;
      onTextSelected?.call(ReaderSelection.fromMap(data));
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onSelectionCleared',
    callback: (_) => onTextDeselected?.call(),
  );

  controller.addJavaScriptHandler(
    handlerName: 'onClick',
    callback: (args) {
      if (args.isEmpty) return;
      final data = args.first as Map<String, dynamic>;
      final x = (data['x'] as num?)?.toDouble();
      final y = (data['y'] as num?)?.toDouble();
      if (x == null || y == null) return;
      onTapped?.call(x, y);
    },
  );
}

/// Base [InAppWebViewSettings] shared by both reader WebViews: zoom off,
/// transparent background, hybrid composition, JS enabled, DevTools
/// inspectable only in debug. The article reader additionally opts into
/// [mixedContentMode] so `https://` article images render inside the
/// `http://127.0.0.1` localhost page.
InAppWebViewSettings baseReaderSettings({
  MixedContentMode? mixedContentMode,
}) => InAppWebViewSettings(
  supportZoom: false,
  transparentBackground: true,
  isInspectable: kDebugMode,
  useHybridComposition: true,
  javaScriptEnabled: true,
  mixedContentMode: mixedContentMode,
);
