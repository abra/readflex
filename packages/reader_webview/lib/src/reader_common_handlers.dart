import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader_bridge.dart';

/// Registers the three JS→Flutter handlers that are identical between the
/// book and article WebViews: [onSelectionEnd], [onSelectionCleared], [onClick].
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

/// Common [InAppWebViewSettings] shared by both reader WebViews.
/// Article reader additionally passes [mixedContentMode] to allow
/// https images inside an http-served page.
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
