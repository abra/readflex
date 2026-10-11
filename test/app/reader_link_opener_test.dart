import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/reader_link_opener.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  LaunchMode? modeFor(String url) => readerLinkLaunchMode(Uri.parse(url));

  test('web pages open in the in-app browser', () {
    expect(
      modeFor('https://en.wikipedia.org/wiki/A'),
      LaunchMode.inAppBrowserView,
    );
    expect(modeFor('http://example.com'), LaunchMode.inAppBrowserView);
    expect(modeFor('HTTPS://Example.com'), LaunchMode.inAppBrowserView);
  });

  test('email and phone links open in their apps', () {
    expect(
      modeFor('mailto:editor@example.com'),
      LaunchMode.externalApplication,
    );
    expect(modeFor('tel:+15550100'), LaunchMode.externalApplication);
  });

  test('other schemes never open', () {
    for (final url in [
      'javascript:alert(1)',
      'file:///etc/hosts',
      'intent://scan#Intent;scheme=zxing;end',
      'ftp://example.com',
      'data:text/html,hi',
    ]) {
      expect(modeFor(url), isNull, reason: url);
    }
  });

  test('a link that is not a URL is ignored without throwing', () async {
    await openReaderLink('http://[::1');
    await openReaderLink('javascript:alert(1)');
  });
}
