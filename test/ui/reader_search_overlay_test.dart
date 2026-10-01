import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_navigation_bar.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

void main() {
  late UiTestApp app;
  setUp(() async {
    app = await UiTestApp.create();
    await app.readerServer.start();
    await app.articleRepository.addExtractedArticle(ReadingFixture.article);
  });
  tearDown(() => app.dispose());

  for (final article in [false, true]) {
    testWidgets(
      '${article ? 'article' : 'book'} search overlays the mounted viewport and never resizes it',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previous = InAppWebViewPlatform.instance;
        final platform = _Platform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          if (previous != null) InAppWebViewPlatform.instance = previous;
        });
        await tester.pumpWidget(app.widget);
        await tapUi(
          tester,
          article
              ? find.text(ReadingFixture.articleTitle)
              : find.byKey(ValueKey('library-grid-${app.book!.id}')),
        );
        await waitForUi(
          tester,
          () =>
              platform.views.isNotEmpty &&
              platform.views.single.controller.handlers.containsKey(
                'onLoadEnd',
              ),
          description: 'reader platform mounted',
        );
        final native = platform.views.single;
        native.controller.handlers['onLoadEnd']!([]);
        await tester.pumpAndSettle();
        final webView = find.byType(
          article ? ArticleHtmlReaderWebView : BookReaderWebView,
        );
        final originalState = tester.state(webView);
        final originalBounds = tester.getRect(webView);
        final search = tester.element(webView).read<ReaderSearchCubit>();
        search.recentQuerySelected(
          'vision',
          searchBook: (_) => Stream.fromIterable([
            const ReaderSearchResults(
              requestId: 1,
              results: [
                ReaderSearchResult(
                  cfi: 'first',
                  excerpt: ReaderSearchExcerpt(match: 'vision'),
                ),
                ReaderSearchResult(
                  cfi: 'second',
                  excerpt: ReaderSearchExcerpt(match: 'vision'),
                ),
              ],
            ),
            const ReaderSearchDone(requestId: 1),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 50));
        search.resultSelected(
          index: 0,
          returnLocation: const ReaderSearchLocation(
            cfi: 'origin',
            fraction: 0.12,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReaderSearchNavigationBar), findsOneWidget);
        expect(
          tester.getRect(webView),
          originalBounds,
          reason: 'Starting match navigation must not repaginate the reader',
        );
        expect(tester.state(webView), same(originalState));
        final fraction =
            tester.getSize(find.byType(ReaderSearchNavigationBar)).height /
            originalBounds.height;
        expect(
          native.controller.scripts.lastWhere(
            (s) => s.contains('setSearchOverlayInset'),
          ),
          contains('setSearchOverlayInset($fraction)'),
        );
        final overlayUpdates = native.controller.scripts
            .where((s) => s.contains('setSearchOverlayInset'))
            .length;

        search.resultSelected(index: 1);
        await tester.pumpAndSettle();
        expect(tester.getRect(webView), originalBounds);
        expect(
          native.controller.scripts
              .where((s) => s.contains('setSearchOverlayInset'))
              .length,
          overlayUpdates,
          reason: 'Match changes need no viewport bridge update',
        );
        final ui = tester.element(webView).read<ReaderUiCubit>();
        ui.openSearchDrawer();
        await tester.pumpAndSettle();
        expect(tester.getRect(webView), originalBounds);
        expect(
          native.controller.scripts.lastWhere(
            (s) => s.contains('setSearchOverlayInset'),
          ),
          contains('setSearchOverlayInset(0.0)'),
        );
        ui.closeSearchDrawer();
        await tester.pumpAndSettle();
        expect(
          native.controller.scripts.lastWhere(
            (s) => s.contains('setSearchOverlayInset'),
          ),
          contains('setSearchOverlayInset($fraction)'),
        );

        tester.view.physicalSize = const Size(844, 390);
        tester.view.padding = const FakeViewPadding(bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(tester.getSize(webView).height, 390);
        expect(tester.state(webView), same(originalState));
        final landscapeFraction =
            tester.getSize(find.byType(ReaderSearchNavigationBar)).height / 390;
        expect(
          native.controller.scripts.lastWhere(
            (s) => s.contains('setSearchOverlayInset'),
          ),
          contains('setSearchOverlayInset($landscapeFraction)'),
        );
        tester.view.physicalSize = const Size(390, 844);
        tester.view.resetPadding();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('End search'));
        await tester.pumpAndSettle();
        expect(find.byType(ReaderSearchNavigationBar), findsNothing);
        expect(tester.getRect(webView), originalBounds);
        expect(tester.state(webView), same(originalState));
        expect(
          native.controller.scripts.lastWhere(
            (s) => s.contains('setSearchOverlayInset'),
          ),
          contains('setSearchOverlayInset(0.0)'),
        );
        // The plugin creates configuration objects on rebuild; only the
        // platform widget retained by its State is actually mounted.
        expect(platform.views.where((view) => view.created), [native]);
        expect(tester.takeException(), isNull);
        await unmountUi(tester);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
}

class _Platform extends InAppWebViewPlatform {
  final views = <_WebView>[];
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final view = _WebView(params);
    views.add(view);
    return view;
  }
}

class _WebView extends PlatformInAppWebViewWidget {
  _WebView(super.params) : super.implementation();
  final controller = _Controller();
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
