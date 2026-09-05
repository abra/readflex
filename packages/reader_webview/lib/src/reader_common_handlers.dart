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

String? parseReaderExternalLinkPayload(Object? raw) {
  final value = switch (raw) {
    String() => raw,
    _ => readerBridgeMap(raw)?['href'],
  };
  if (value is! String) return null;
  final href = value.trim();
  return href.isEmpty ? null : href;
}

@visibleForTesting
const currentReaderTextSelectionScript = '''
(() => {
  try {
    return typeof window.getCurrentTextSelection === 'function'
      ? window.getCurrentTextSelection()
      : null;
  } catch (error) {
    console.error('[readflex-eval:currentTextSelection]', error);
    return null;
  }
})()
''';

Future<ReaderSelection?> readCurrentReaderTextSelection(
  InAppWebViewController? controller,
) async {
  if (controller == null) return null;
  try {
    final raw = await controller.evaluateJavascript(
      source: currentReaderTextSelectionScript,
    );
    return parseReaderSelectionPayload(raw);
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[reader-selection-dart] live selection failed: $error');
    }
    return null;
  }
}

/// Ignores callbacks from a disposed or superseded native WebView.
final class ReaderHandlerScope {
  const ReaderHandlerScope(this.controller, {required this.isActive});

  final InAppWebViewController controller;
  final bool Function() isActive;

  void add({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    controller.addJavaScriptHandler(
      handlerName: handlerName,
      callback: (args) {
        if (!isActive()) return null;
        return callback(args);
      },
    );
  }
}

/// Wires selection and tap bridge messages to the active reader callbacks.
void registerSharedReaderHandlers(
  InAppWebViewController controller, {
  void Function(ReaderSelection)? onTextSelected,
  VoidCallback? onTextDeselected,
  void Function(double x, double y)? onTapped,
  bool Function()? isActive,
}) {
  final handlers = ReaderHandlerScope(
    controller,
    isActive: isActive ?? () => true,
  );
  if (readerTextSelectionTracingEnabled) {
    handlers.add(
      handlerName: 'onTextSelectionDebug',
      callback: (args) {
        final payload = args.isEmpty ? const <String, Object?>{} : args.first;
        debugPrint('[reader-selection-js] ${jsonEncode(payload)}');
      },
    );
  }

  handlers.add(
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

  handlers.add(
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

  handlers.add(
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
/// transparent background, texture-layer composition on Android, JS enabled,
/// native text action menu off, DevTools inspectable only in debug.
InAppWebViewSettings baseReaderSettings() => InAppWebViewSettings(
  supportZoom: false,
  transparentBackground: true,
  isInspectable: kDebugMode,
  useHybridComposition: false,
  useOnRenderProcessGone: true,
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
