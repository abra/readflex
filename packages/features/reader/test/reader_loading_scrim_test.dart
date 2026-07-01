import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reader loading is owned by a single outer scrim', () {
    final screenSource = _readSource(packagePath: 'lib/src/reader_screen.dart');
    final contentSource = _readSource(
      packagePath: 'lib/src/reader_screen_content.dart',
    );

    expect(
      screenSource,
      contains('_kReaderWebViewRouteMountDelay = Duration.zero'),
    );
    expect(screenSource, contains('_kReaderLoadingIconSize = 28.0'));
    expect(screenSource, contains('_kReaderLoadingScrimFadeDuration'));
    expect(contentSource, contains('class _ReaderLoadingScrim'));
    expect(contentSource, contains('class _ReaderLoadingMark'));
    expect(contentSource, contains('AppIcons.book'));
    expect(contentSource, contains('opacity: loadingVisible ? 1 : 0'));
    expect(contentSource, contains('widget.onWebViewReady(sourceId)'));
    expect(
      _occurrences(contentSource, '_ReaderLoadingScrim(theme:'),
      1,
    );
    expect(
      contentSource,
      isNot(contains('Center(child: _ReaderLoadingIndicator')),
    );
    expect(contentSource, isNot(contains('CircularProgressIndicator')));
    expect(contentSource, isNot(contains('_ReaderLoadingIndicator')));
    expect(contentSource, isNot(contains('width: 28')));
    expect(contentSource, isNot(contains('height: 28')));
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

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}
