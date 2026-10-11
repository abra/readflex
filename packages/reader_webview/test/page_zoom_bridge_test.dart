import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:reader_webview/src/page_touch_tap_forwarder.dart';

import 'support/fake_inappwebview_platform.dart';

/// Comic and PDF pages share the zoom bridge: iOS forwards completed taps so
/// double-tap zoom survives WKWebView dropping the second touch, and both
/// formats serve page previews. Text books keep neither.
void main() {
  late FakeInAppWebViewPlatform platform;
  final key = GlobalKey<BookReaderWebViewState>();

  setUp(() {
    final previous = InAppWebViewPlatform.instance;
    platform = FakeInAppWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
  });

  Future<FakeInAppWebView> mount(
    WidgetTester tester, {
    required bool zoomablePages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookReaderWebView(
          key: key,
          serverBaseUri: Uri.parse('http://127.0.0.1:1234/r/token/'),
          bookFilePath: '/books/a.pdf',
          zoomablePages: zoomablePages,
        ),
      ),
    );
    await tester.pump();
    return platform.views.single;
  }

  bool hostTapsIn(FakeInAppWebView view) {
    final url = view.params.initialUrlRequest!.url!;
    return jsonDecode(url.queryParameters['pageHostTaps']!) as bool;
  }

  testWidgets(
    'iOS forwards taps on zoomable pages to the page zoom',
    (tester) async {
      final view = await mount(tester, zoomablePages: true);
      expect(hostTapsIn(view), isTrue);
      expect(find.byType(PageTouchTapForwarder), findsOneWidget);

      view.emit('onLoadEnd', []);
      final gesture = await tester.startGesture(const Offset(120, 300));
      await gesture.up(timeStamp: const Duration(milliseconds: 40));
      await tester.pump();
      expect(
        view.nativeController.scripts.where(
          (script) =>
              script.contains('window.handlePageTouchTap?.(120.0, 300.0)'),
        ),
        hasLength(1),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android zoomable pages keep their own WebView taps',
    (tester) async {
      final view = await mount(tester, zoomablePages: true);
      expect(hostTapsIn(view), isFalse);
      expect(find.byType(PageTouchTapForwarder), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS text books keep their own WebView taps',
    (tester) async {
      final view = await mount(tester, zoomablePages: false);
      expect(hostTapsIn(view), isFalse);
      expect(find.byType(PageTouchTapForwarder), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('page previews decode bounded JPEG data from the open page', (
    tester,
  ) async {
    final view = await mount(tester, zoomablePages: true);
    final state = key.currentState!;
    expect(await state.pageThumbnail(2), isNull, reason: 'not ready yet');

    view.emit('onLoadEnd', []);
    view.nativeController.asyncResult =
        'data:image/jpeg;base64,${base64Encode([1, 2, 3])}';
    expect(await state.pageThumbnail(2), [1, 2, 3]);
    expect(
      view.nativeController.asyncCalls.single.$1,
      contains('readflexPageThumbnail'),
    );
    expect(view.nativeController.asyncCalls.single.$2, {'index': 2});

    view.nativeController.asyncResult = 'data:image/png;base64,AQID';
    expect(await state.pageThumbnail(2), isNull, reason: 'only JPEG');
    view.nativeController.asyncResult =
        'data:image/jpeg;base64,${'A' * (128 * 1024)}';
    expect(await state.pageThumbnail(2), isNull, reason: 'over the limit');
    expect(await state.pageThumbnail(-1), isNull);
  });

  testWidgets('text books never ask for page previews', (tester) async {
    final view = await mount(tester, zoomablePages: false);
    view.emit('onLoadEnd', []);
    expect(await key.currentState!.pageThumbnail(0), isNull);
    expect(view.nativeController.asyncCalls, isEmpty);
  });
}
