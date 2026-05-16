import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';

/// Registers the three JS → Flutter bridge handlers that the reader
/// WebView fires — `onSelectionEnd`, `onSelectionCleared`, `onClick` —
/// and wires each one to the provided Dart callback.
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
      final data = readerBridgeMap(args.first);
      if (data == null) return;
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
      final data = readerBridgeMap(args.first);
      if (data == null) return;
      final x = data['x'];
      final y = data['y'];
      if (x is! num || y is! num) return;
      onTapped?.call(x.toDouble(), y.toDouble());
    },
  );
}

/// Base [InAppWebViewSettings] for the reader WebView: zoom off,
/// transparent background, hybrid composition, JS enabled, DevTools
/// inspectable only in debug.
InAppWebViewSettings baseReaderSettings() => InAppWebViewSettings(
  supportZoom: false,
  transparentBackground: true,
  isInspectable: kDebugMode,
  useHybridComposition: true,
  javaScriptEnabled: true,
);
