import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('article system background avoids fades over article content', () {
    final contentSource = _readSource(
      packagePath: 'lib/src/reader_screen_content.dart',
    );

    expect(contentSource, contains('_ArticleSystemBarBackground'));
    expect(contentSource, contains('child: ColoredBox(color: color)'));
    expect(contentSource, contains('height: padding.top'));
    expect(contentSource, isNot(contains('height: padding.bottom')));
    expect(contentSource, isNot(contains('LinearGradient')));
    expect(contentSource, isNot(contains('color.withValues(alpha: 0)')));
    expect(
      contentSource,
      isNot(contains('_kArticleStatusBarFadeHeight')),
    );
    expect(
      contentSource,
      isNot(contains('_kArticleNavigationBarFadeHeight')),
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
