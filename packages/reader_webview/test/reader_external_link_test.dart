import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

import 'support/fake_inappwebview_platform.dart';

void main() {
  late FakeInAppWebViewPlatform platform;

  setUp(() {
    final previous = InAppWebViewPlatform.instance;
    platform = FakeInAppWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
  });

  final base = Uri.parse('http://127.0.0.1:1234/r/token/');

  for (final article in [true, false]) {
    final label = article ? 'article' : 'book';

    testWidgets('$label forwards JS external links to the widget callback', (
      tester,
    ) async {
      final links = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: article
              ? ArticleHtmlReaderWebView(
                  serverBaseUri: base,
                  articleFilePath: '/articles/a/content.html',
                  onExternalLink: links.add,
                )
              : BookReaderWebView(
                  serverBaseUri: base,
                  bookFilePath: '/books/a.epub',
                  onExternalLink: links.add,
                ),
        ),
      );
      final view = platform.views.single;
      expect(view.nativeController.handlers, contains('onExternalLink'));
      view.emit('onExternalLink', ['https://example.com/a#b']);
      view.emit('onExternalLink', [
        {'href': ' https://example.com/legacy '},
      ]);
      view.emit('onExternalLink', ['   ']);
      view.emit('onExternalLink', []);
      expect(links, ['https://example.com/a#b', 'https://example.com/legacy']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$label polices navigation and forwards external pages', (
      tester,
    ) async {
      final links = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: article
              ? ArticleHtmlReaderWebView(
                  serverBaseUri: base,
                  articleFilePath: '/articles/a/content.html',
                  onExternalLink: links.add,
                )
              : BookReaderWebView(
                  serverBaseUri: base,
                  bookFilePath: '/books/a.epub',
                  onExternalLink: links.add,
                ),
        ),
      );
      final view = platform.views.single;
      final params = view.params;
      expect(params.initialSettings!.useShouldOverrideUrlLoading, isTrue);
      final handler = params.shouldOverrideUrlLoading!;

      Future<NavigationActionPolicy?> navigate(
        String url, {
        bool mainFrame = true,
      }) => handler(
        view.controller,
        NavigationAction(
          request: URLRequest(url: WebUri(url)),
          isForMainFrame: mainFrame,
        ),
      );

      expect(
        await navigate(params.initialUrlRequest!.url!.toString()),
        NavigationActionPolicy.ALLOW,
      );
      expect(
        await navigate('blob:http://127.0.0.1:1234/section', mainFrame: false),
        NavigationActionPolicy.ALLOW,
      );
      expect(await navigate('about:blank'), NavigationActionPolicy.ALLOW);
      expect(
        await navigate('https://example.com/frame', mainFrame: false),
        NavigationActionPolicy.CANCEL,
      );
      expect(
        await navigate('javascript:alert(1)'),
        NavigationActionPolicy.CANCEL,
      );
      expect(links, isEmpty);
      expect(
        await navigate('https://example.com/page'),
        NavigationActionPolicy.CANCEL,
      );
      expect(links, ['https://example.com/page']);

      // A replaced renderer cannot open links through its stale controller.
      view.crash();
      await tester.pump();
      expect(platform.views, hasLength(2));
      expect(
        await navigate('https://example.com/stale'),
        NavigationActionPolicy.CANCEL,
      );
      expect(links, ['https://example.com/page']);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
