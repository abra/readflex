import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ReaderTestPlatform extends InAppWebViewPlatform {
  ReaderTestPlatform({this.onAsyncJavaScript});

  final Future<CallAsyncJavaScriptResult?> Function(
    String body,
    Map<String, dynamic> arguments,
  )?
  onAsyncJavaScript;

  final views = <_WebView>[];
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final view = _WebView(params, _Controller(onAsyncJavaScript));
    views.add(view);
    return view;
  }
}

class _WebView extends PlatformInAppWebViewWidget {
  _WebView(super.params, this.controller) : super.implementation();
  final _Controller controller;
  bool created = false;
  @override
  Widget build(BuildContext context) => _NativeView(this);

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;
  @override
  void dispose() {}
}

// Like AndroidView/UiKitView, native creation belongs to the mounted State,
// not to every new plugin configuration produced by a parent rebuild.
class _NativeView extends StatefulWidget {
  const _NativeView(this.owner);
  final _WebView owner;
  @override
  State<_NativeView> createState() => _NativeViewState();
}

class _NativeViewState extends State<_NativeView> {
  @override
  void initState() {
    super.initState();
    final owner = widget.owner;
    owner.created = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      owner.params.onWebViewCreated?.call(
        owner.controllerFromPlatform<InAppWebViewController>(owner.controller),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _Controller extends PlatformInAppWebViewController {
  _Controller(this.onAsyncJavaScript)
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 1),
      );
  final Future<CallAsyncJavaScriptResult?> Function(
    String body,
    Map<String, dynamic> arguments,
  )?
  onAsyncJavaScript;
  final handlers = <String, JavaScriptHandlerCallback>{};
  final scripts = <String>[];
  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) => handlers[handlerName] = callback;
  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    scripts.add(source);
    return null;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async => onAsyncJavaScript?.call(functionBody, arguments);
}
