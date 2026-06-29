import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('article system scrim uses lightweight system bar fades', () {
    final screenSource = _readSource(packagePath: 'lib/src/reader_screen.dart');
    final contentSource = _readSource(
      packagePath: 'lib/src/reader_screen_content.dart',
    );

    expect(screenSource, contains('_kArticleStatusBarFadeHeight = 28.0'));
    expect(
      screenSource,
      contains('_kArticleNavigationBarFadeHeight = 28.0'),
    );
    expect(contentSource, contains('child: ColoredBox(color: color)'));
    expect(contentSource, contains('height: _kArticleStatusBarFadeHeight'));
    expect(
      contentSource,
      contains('height: _kArticleNavigationBarFadeHeight'),
    );
    expect(contentSource, contains('gradient: LinearGradient'));
    expect(contentSource, contains('begin: Alignment.topCenter'));
    expect(contentSource, contains('end: Alignment.bottomCenter'));
    expect(contentSource, contains('color.withValues(alpha: 0)'));
    expect(contentSource, contains('bottom: padding.bottom'));
    expect(contentSource, contains('height: padding.bottom'));
    expect(
      'if (padding.bottom > 0)'.allMatches(contentSource),
      hasLength(1),
    );
    expect(contentSource, isNot(contains('BackdropFilter')));
  });

  test('article reader uses compact vertical margins', () {
    final screenSource = _readSource(packagePath: 'lib/src/reader_screen.dart');
    final contentSource = _readSource(
      packagePath: 'lib/src/reader_screen_content.dart',
    );

    expect(screenSource, contains('_kArticleReaderTopMargin = 32.0'));
    expect(screenSource, contains('_kArticleReaderBottomMargin = 40.0'));
    expect(contentSource, contains('double? topMargin'));
    expect(contentSource, contains('double? bottomMargin'));
    expect(contentSource, contains('topMargin: topMargin ?? layout.topMargin'));
    expect(
      contentSource,
      contains('bottomMargin: bottomMargin ?? layout.bottomMargin'),
    );
    expect(contentSource, contains('topMargin: _kArticleReaderTopMargin'));
    expect(
      contentSource,
      contains('bottomMargin: _kArticleReaderBottomMargin'),
    );
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
