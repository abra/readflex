import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';

const readerTextSelectionTracingEnabled =
    kDebugMode && bool.fromEnvironment('READFLEX_TRACE_TEXT_SELECTION');

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
  if (readerTextSelectionTracingEnabled) {
    controller.addJavaScriptHandler(
      handlerName: 'onTextSelectionDebug',
      callback: (args) {
        final payload = args.isEmpty ? const <String, Object?>{} : args.first;
        debugPrint('[reader-selection-js] ${jsonEncode(payload)}');
      },
    );
  }

  controller.addJavaScriptHandler(
    handlerName: 'onSelectionEnd',
    callback: (args) {
      if (readerTextSelectionTracingEnabled) {
        debugPrint(
          '[reader-selection-dart] onSelectionEnd '
          'args=${args.length} callback=${onTextSelected != null}',
        );
      }
      if (args.isEmpty) {
        if (readerTextSelectionTracingEnabled) {
          debugPrint('[reader-selection-dart] dropped: empty payload');
        }
        return;
      }
      final selection = parseReaderSelectionPayload(args.first);
      if (selection == null) {
        if (readerTextSelectionTracingEnabled) {
          debugPrint(
            '[reader-selection-dart] dropped: invalid payload '
            '${jsonEncode(args.first)}',
          );
        }
        return;
      }
      if (readerTextSelectionTracingEnabled) {
        debugPrint(
          '[reader-selection-dart] parsed '
          'text=${selection.text.length} '
          'cfi=${selection.normalizedCfiRange ?? selection.cfiRange}',
        );
      }
      onTextSelected?.call(selection);
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onSelectionCleared',
    callback: (_) {
      if (readerTextSelectionTracingEnabled) {
        debugPrint(
          '[reader-selection-dart] onSelectionCleared '
          'callback=${onTextDeselected != null}',
        );
      }
      onTextDeselected?.call();
    },
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
/// transparent background, hybrid composition, JS enabled, native text
/// action menu off, DevTools inspectable only in debug.
InAppWebViewSettings baseReaderSettings() => InAppWebViewSettings(
  supportZoom: false,
  transparentBackground: true,
  isInspectable: kDebugMode,
  useHybridComposition: true,
  javaScriptEnabled: true,
  disableContextMenu: true,
  disableLongPressContextMenuOnLinks: true,
);

/// Hides default native edit-menu items such as iOS "Copy Link with Highlight"
/// while keeping WebView text selection available for the reader popup.
ContextMenu readerContextMenu() => ContextMenu(
  settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
);

bool shouldLogReaderWebViewConsoleMessage({
  required bool debugMode,
  required String level,
}) {
  if (!debugMode) return false;
  return level.toLowerCase().contains('error') ||
      level.toLowerCase().contains('warning');
}
