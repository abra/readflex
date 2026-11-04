import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS document picker registers supported comic aliases', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('com.readflex.cbz'));
    expect(infoPlist, contains('<string>cbz</string>'));
  });

  test('iOS document picker registers both DjVu extensions', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(infoPlist, contains('com.readflex.djvu'));
    expect(infoPlist, contains('<string>djvu</string>'));
    expect(infoPlist, contains('<string>djv</string>'));
    expect(infoPlist, contains('image/vnd.djvu'));
  });
}
