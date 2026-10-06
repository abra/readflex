import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/src/reader_navigation_policy.dart';

void main() {
  final policy = ReaderNavigationPolicy(
    serverBaseUri: _serverBase,
  );

  ReaderNavigationDecision decide(String url, {bool mainFrame = true}) =>
      policy.decide(url: Uri.parse(url), isForMainFrame: mainFrame);

  group('ReaderNavigationPolicy', () {
    test('allows the reader server origin in main and sub frames', () {
      for (final url in [
        'http://127.0.0.1:4321/r/token/assets/article-html/index.html?x=1',
        'http://127.0.0.1:4321/r/token/book/%2Fbooks%2Fa.epub',
        'http://127.0.0.1:4321/r/other-token/article/dir/content.html',
        'HTTP://127.0.0.1:4321/anything',
      ]) {
        expect(decide(url), ReaderNavigationDecision.allow, reason: url);
        expect(
          decide(url, mainFrame: false),
          ReaderNavigationDecision.allow,
          reason: url,
        );
      }
    });

    test('allows loader-generated opaque documents', () {
      for (final url in [
        'about:blank',
        'about:srcdoc',
        'blob:http://127.0.0.1:4321/4a5b',
        'data:text/html,<p>x</p>',
      ]) {
        expect(decide(url), ReaderNavigationDecision.allow, reason: url);
        expect(
          decide(url, mainFrame: false),
          ReaderNavigationDecision.allow,
          reason: url,
        );
      }
    });

    test('forwards external http(s) main-frame navigation', () {
      expect(
        decide('https://example.com/page'),
        ReaderNavigationDecision.cancelAndOpenExternally,
      );
      expect(
        decide('http://example.com/page'),
        ReaderNavigationDecision.cancelAndOpenExternally,
      );
    });

    test('rejects loopback look-alikes on another port or host', () {
      expect(
        decide('http://127.0.0.1:4322/r/token/'),
        ReaderNavigationDecision.cancelAndOpenExternally,
      );
      expect(
        decide('https://127.0.0.1:4321/r/token/'),
        ReaderNavigationDecision.cancelAndOpenExternally,
      );
      expect(
        decide('http://localhost:4321/r/token/'),
        ReaderNavigationDecision.cancelAndOpenExternally,
      );
    });

    test('cancels external sub-frame loads without opening them', () {
      expect(
        decide('https://example.com/frame', mainFrame: false),
        ReaderNavigationDecision.cancel,
      );
    });

    test('cancels non-web schemes and missing URLs', () {
      for (final url in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'mailto:someone@example.com',
        'intent://scan/#Intent;scheme=zxing;end',
      ]) {
        expect(decide(url), ReaderNavigationDecision.cancel, reason: url);
      }
      expect(
        policy.decide(url: null, isForMainFrame: true),
        ReaderNavigationDecision.cancel,
      );
    });
  });
}

final _serverBase = Uri.parse('http://127.0.0.1:4321/r/token/');
