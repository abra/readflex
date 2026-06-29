import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('article system scrim uses a lightweight status bar fade', () {
    final screenSource = _readSource(packagePath: 'lib/src/reader_screen.dart');
    final contentSource = _readSource(
      packagePath: 'lib/src/reader_screen_content.dart',
    );

    expect(screenSource, contains('_kArticleStatusBarFadeHeight = 28.0'));
    expect(contentSource, contains('child: ColoredBox(color: color)'));
    expect(contentSource, contains('height: _kArticleStatusBarFadeHeight'));
    expect(contentSource, contains('gradient: LinearGradient'));
    expect(contentSource, contains('begin: Alignment.topCenter'));
    expect(contentSource, contains('end: Alignment.bottomCenter'));
    expect(contentSource, contains('color.withValues(alpha: 0)'));
    expect(contentSource, isNot(contains('BackdropFilter')));
  });
}

String _readSource({required String packagePath}) {
  final candidates = [
    File(packagePath),
    File('packages/features/reader/$packagePath'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Reader source file not found: $packagePath');
}
