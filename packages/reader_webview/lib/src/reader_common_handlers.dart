import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';

@visibleForTesting
final class ReaderTapPayload {
  const ReaderTapPayload({required this.x, required this.y});

  final double x;
  final double y;
}

@visibleForTesting
ReaderSelection? parseReaderSelectionPayload(Object? raw) {
  final data = readerBridgeMap(raw);
  if (data == null) return null;
  return ReaderSelection.fromMap(data);
}

@visibleForTesting
ReaderTapPayload? parseReaderTapPayload(Object? raw) {
  final data = readerBridgeMap(raw);
  if (data == null) return null;
  final x = data['x'];
  final y = data['y'];
  if (x is! num || y is! num) return null;
  return ReaderTapPayload(x: x.toDouble(), y: y.toDouble());
}

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
      final selection = parseReaderSelectionPayload(args.first);
      if (selection == null) return;
      onTextSelected?.call(selection);
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
      final tap = parseReaderTapPayload(args.first);
      if (tap == null) return;
      onTapped?.call(tap.x, tap.y);
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
