import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Platform-interface fakes shared by reader widget tests. They record
/// registered JS handlers, evaluated scripts and creation params so tests can
/// drive the bridge without a native WebView.
class FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  final views = <FakeInAppWebView>[];
  FakeHeadlessInAppWebView? headless;

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) {
    return headless = FakeHeadlessInAppWebView(params);
  }

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final view = FakeInAppWebView(params);
    views.add(view);
    return view;
  }
}

class FakeHeadlessInAppWebView extends PlatformHeadlessInAppWebView {
  FakeHeadlessInAppWebView(super.params) : super.implementation();

  bool disposed = false;
  @override
  final FakeInAppWebViewController webViewController =
      FakeInAppWebViewController();

  @override
  Future<void> run() async {
    final controller = params.controllerFromPlatform!(webViewController);
    params.onRenderProcessGone!(
      controller,
      RenderProcessGoneDetail(didCrash: true),
    );
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeInAppWebView extends PlatformInAppWebViewWidget {
  FakeInAppWebView(super.params) : super.implementation();

  final nativeController = FakeInAppWebViewController();
  late final controller = controllerFromPlatform<InAppWebViewController>(
    nativeController,
  );
  bool created = false;
  bool disposed = false;

  @override
  Widget build(BuildContext context) {
    if (!created) {
      created = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => params.onWebViewCreated?.call(controller),
      );
    }
    return const SizedBox.expand();
  }

  void emit(String name, List<dynamic> args) =>
      nativeController.handlers[name]!(args);
  void crash() => params.onRenderProcessGone!(
    controller,
    RenderProcessGoneDetail(didCrash: true),
  );

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() => disposed = true;
}

class FakeInAppWebViewController extends PlatformInAppWebViewController {
  FakeInAppWebViewController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 1),
      );

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
}
