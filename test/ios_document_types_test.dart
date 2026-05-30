import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS document picker registers supported comic aliases', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('com.readflex.cbz'));
    expect(infoPlist, contains('<string>cbz</string>'));
  });
}
