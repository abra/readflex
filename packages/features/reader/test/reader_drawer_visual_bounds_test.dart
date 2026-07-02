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
      beforeMarker: '/// Compact empty-state',
    );

    expect(frameSource, contains('return Material('));
    expect(frameSource, contains('color: Colors.transparent'));
    expect(frameSource, contains('clipBehavior: Clip.hardEdge'));
    expect(frameSource, contains('DecoratedBox('));
  });

  test('image-area highlights can use note as drawer title', () {
    final source = _readSource(
      packagePath: 'lib/src/reader_screen_drawers.dart',
    );
    final tileSource = _classSource(
      source,
      className: '_ReaderHighlightListTile',
      beforeMarker: 'class _ReaderHighlightColorDot',
    );

    expect(tileSource, contains('highlight.kind == HighlightKind.imageArea'));
    expect(tileSource, contains('notePromotedToTitle'));
    expect(
      tileSource,
      contains('final title = notePromotedToTitle ? note : fallbackTitle;'),
    );
    expect(tileSource, contains('title,'));
  });
}

String _classSource(
  String source, {
  required String className,
  required String beforeMarker,
}) {
  final start = source.indexOf('class $className');
  final end = source.indexOf(beforeMarker, start);

  expect(start, isNot(-1), reason: 'Expected $className to exist');
  expect(end, isNot(-1), reason: 'Expected marker after $className');

  return source.substring(start, end);
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
