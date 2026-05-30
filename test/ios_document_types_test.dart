import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS document picker registers DjVu aliases', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      infoPlist,
      matches(
        RegExp(
          r'<key>UTTypeIdentifier</key>\s*'
          r'<string>com\.readflex\.djvu</string>[\s\S]*?'
          r'<key>public\.filename-extension</key>\s*'
          r'<array>[\s\S]*?'
          r'<string>djvu</string>[\s\S]*?'
          r'<string>djv</string>[\s\S]*?'
          r'</array>[\s\S]*?'
          r'<key>public\.mime-type</key>\s*'
          r'<array>[\s\S]*?'
          r'<string>image/vnd\.djvu</string>',
        ),
      ),
    );
  });
}
