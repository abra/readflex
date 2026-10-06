import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drawer content frame clips local Material ink effects', () {
    final source = _readSource(
      packagePath: 'lib/src/reader_screen_drawers.dart',
    );
    final frameSource = _classSource(
      source,
      className: '_ReaderDrawerContentFrame',
    );

    expect(frameSource, contains('return Material('));
    expect(frameSource, contains('color: Colors.transparent'));
    expect(frameSource, contains('clipBehavior: Clip.hardEdge'));
    expect(frameSource, contains('DecoratedBox('));
  });

  test('drawer placeholders use the shared EmptyState', () {
    final source = _readSource(
      packagePath: 'lib/src/reader_screen_drawers.dart',
    );
    expect(source, isNot(contains('_ReaderDrawerEmptyState')));
    expect('EmptyState(\n'.allMatches(source).length, 3);
    expect('compact: true,'.allMatches(source).length, 3);
  });

  // Image-area title promotion is exercised with the real widget and copy
  // action in reader_highlight_list_tile_test.dart, not source-string matching.
}

String _classSource(String source, {required String className}) {
  final start = source.indexOf('class $className');
  expect(start, isNot(-1), reason: 'Expected $className to exist');
  final next = source.indexOf('\nclass ', start + 1);

  return next == -1 ? source.substring(start) : source.substring(start, next);
}

String _readSource({required String packagePath}) {
  final candidates = [
    File(packagePath),
    File('packages/features/reader/$packagePath'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file.readAsStringSync();
  }

  throw StateError('Unable to find $packagePath');
}
