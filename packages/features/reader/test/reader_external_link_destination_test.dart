import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_external_link_destination.dart';

void main() {
  ReaderExternalLinkDestination parse(String url) =>
      ReaderExternalLinkDestination.tryParse(url)!;

  test('a web link shows its host and its whole address', () {
    final link = parse('https://En.Wikipedia.org/wiki/Lewis_and_Clark');
    expect(link.target, 'en.wikipedia.org');
    expect(link.address, 'https://En.Wikipedia.org/wiki/Lewis_and_Clark');
    expect(link.url, 'https://En.Wikipedia.org/wiki/Lewis_and_Clark');
  });

  test('escapes are decoded for reading, never for opening', () {
    const url = 'https://ru.wikipedia.org/wiki/%D0%AD%D0%BA%D1%81';
    final link = parse(url);
    expect(link.address, 'https://ru.wikipedia.org/wiki/Экс');
    expect(link.url, url);
  });

  test('escaped ASCII stays escaped, so the address says what it is', () {
    // Decoding %3A%2F%2F would put a convincing "https://en.wikipedia.org"
    // inside an address that goes somewhere else.
    const url =
        'https://login.example.net/r?continue=https%3A%2F%2Fen.wikipedia.org'
        '%2Fwiki%2FA%20B&q=%D0%AD';
    expect(
      parse(url).address,
      'https://login.example.net/r?continue=https%3A%2F%2Fen.wikipedia.org'
      '%2Fwiki%2FA%20B&q=Э',
    );
  });

  test('a broken or mixed escape run stays escaped as a whole', () {
    // A lone continuation byte, and a word holding a direction override.
    expect(
      parse('https://a.example/%AD%D0').address,
      'https://a.example/%AD%D0',
    );
    expect(
      parse('https://a.example/%D0%AD%E2%80%AE%D0%BA').address,
      'https://a.example/%D0%AD%E2%80%AE%D0%BA',
    );
  });

  test('an international host keeps the punycode browsers show', () {
    // Pages report URL-API hrefs: the host arrives as punycode.
    expect(
      parse('https://xn--e1afmkfd.xn--p1ai/').target,
      'xn--e1afmkfd.xn--p1ai',
    );
  });

  test('email and phone links show the address and the number', () {
    expect(
      parse('mailto:editor@river.example?subject=Hi').target,
      'editor@river.example',
    );
    expect(
      parse('mailto:editor%40river.example').target,
      'editor@river.example',
    );
    expect(parse('tel:+1-555-0100').target, '+1-555-0100');
  });

  test('surrounding spaces are not part of the link', () {
    expect(parse('  https://example.com/a \n').url, 'https://example.com/a');
  });

  test('a decoded address cannot hide behind invisible characters', () {
    // A right-to-left override would show "exe.png" for "png.exe".
    for (final url in [
      'http://a.example/%E2%80%AEgnp.exe',
      'http://a.example/line%0Abreak',
      'http://a.example/zero%E2%80%8Bwidth',
    ]) {
      expect(parse(url).address, url, reason: url);
    }
  });

  test('an escape that does not decode stays as written', () {
    expect(parse('http://a.example/100%').address, 'http://a.example/100%');
  });

  test('links the reader does not open have no destination', () {
    for (final url in [
      'javascript:alert(1)',
      'file:///etc/hosts',
      'ftp://example.com',
      'data:text/html,hi',
      'intent://scan#Intent;end',
      'blob:https://example.com/1',
      'https:///no-host',
      'mailto:',
      'not a link',
      '',
      'http://[::1',
    ]) {
      expect(ReaderExternalLinkDestination.tryParse(url), isNull, reason: url);
    }
  });
}
