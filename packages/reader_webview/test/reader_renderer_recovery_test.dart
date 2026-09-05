import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  test(
    'metadata extraction reports renderer death during native startup and disposes it',
    () async {
      final previous = InAppWebViewPlatform.instance;
      final platform = _Platform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        if (previous != null) InAppWebViewPlatform.instance = previous;
      });
      final extractor = BookMetadataExtractor(
        serverBaseUri: Uri.parse('http://127.0.0.1:1234/r/token/'),
      );
      await expectLater(
        extractor.extract('/books/a.epub'),
        throwsA(isA<BookImportException>()),
      );
      expect(
        platform.headless!.params.initialSettings!.useOnRenderProcessGone,
        isTrue,
      );
      expect(platform.headless!.disposed, isTrue);
    },
  );

  for (final article in [false, true]) {
    testWidgets(
      '${article ? 'article' : 'book'} replaces a dead renderer and ignores its late events',
      (tester) async {
        final previous = InAppWebViewPlatform.instance;
        final platform = _Platform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          if (previous != null) InAppWebViewPlatform.instance = previous;
        });
        var ready = 0;
        var loading = 0;
        final failures = <ReaderLoadFailure>[];
        final positions = <BookPosition>[];
        final base = Uri.parse('http://127.0.0.1:1234/r/token/');
        final reader = article
            ? ArticleHtmlReaderWebView(
                serverBaseUri: base,
                articleFilePath: '/articles/a/content.html',
                initialPosition: 'initial',
                onReady: () => ready++,
                onLoading: () => loading++,
                onLoadFailed: failures.add,
                onPositionChanged: positions.add,
              )
            : BookReaderWebView(
                serverBaseUri: base,
                bookFilePath: '/books/a.epub',
                initialCfi: 'initial',
                onReady: () => ready++,
                onLoading: () => loading++,
                onLoadFailed: failures.add,
                onPositionChanged: positions.add,
              );
        await tester.pumpWidget(MaterialApp(home: reader));
        final first = platform.views.single;
        expect(first.params.initialSettings!.useOnRenderProcessGone, isTrue);
        first.emit('onLoadEnd', []);
        expect(
          first.nativeController.scripts.where(
            (s) => s.contains('changeStyle('),
          ),
          isEmpty,
        );
        first.emit(article ? 'onArticlePositionChanged' : 'onRelocated', [
          {'cfi': 'latest', 'fraction': 0.7},
        ]);
        first.crash();
        await tester.pump();
        expect(platform.views, hasLength(2));
        expect(first.disposed, isTrue);
        expect(loading, 1);
        final second = platform.views.last;
        final params = second.params.initialUrlRequest!.url!.queryParameters;
        expect(
          jsonDecode(params[article ? 'initialPosition' : 'initialCfi']!),
          'latest',
        );
        first.emit('onReaderLoadFailed', []);
        first.emit('onLoadEnd', []);
        first.emit(article ? 'onArticlePositionChanged' : 'onRelocated', [
          {'cfi': 'stale', 'fraction': 0.1},
        ]);
        expect(ready, 1);
        expect(positions.last.cfi, 'latest');
        expect(failures, isEmpty);
        second.emit('onLoadEnd', []);
        expect(ready, 2);
        second.crash();
        await tester.pump();
        expect(platform.views, hasLength(2));
        expect(failures.single.kind, ReaderLoadFailureKind.rendererTerminated);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}

class _Platform extends InAppWebViewPlatform {
  final views = <_WebView>[];
  _Headless? headless;

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) {
    return headless = _Headless(params);
  }

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final view = _WebView(params);
    views.add(view);
    return view;
  }
}

class _Headless extends PlatformHeadlessInAppWebView {
  _Headless(super.params) : super.implementation();

  bool disposed = false;
  @override
  final _Controller webViewController = _Controller();

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

class _WebView extends PlatformInAppWebViewWidget {
  _WebView(super.params) : super.implementation();

  final nativeController = _Controller();
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

class _Controller extends PlatformInAppWebViewController {
  _Controller()
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
