import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appSourceCoverImageFromPath', () {
    test('returns null for missing path', () {
      expect(appSourceCoverImageFromPath(null), isNull);
      expect(appSourceCoverImageFromPath(''), isNull);
    });

    test('returns FileImage for local path', () {
      final image = appSourceCoverImageFromPath('/tmp/cover.png');

      expect(image, isA<FileImage>());
      expect((image! as FileImage).file.path, '/tmp/cover.png');
    });
  });
}
