import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  late GoldenFileComparator previous;
  setUpAll(() {
    previous = goldenFileComparator;
    final local = previous;
    if (local is LocalFileComparator) {
      goldenFileComparator = _UiGoldenComparator(
        local.basedir.resolve('ui_test.dart'),
      );
    }
  });
  tearDownAll(() => goldenFileComparator = previous);
  await testMain();
}

class _UiGoldenComparator extends LocalFileComparator {
  _UiGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await _capture(imageBytes, golden);
    // Captures are review artifacts; baseline comparison decides success.
    return super.compare(imageBytes, golden);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    await _capture(imageBytes, golden);
    await super.update(golden, imageBytes);
  }

  Future<void> _capture(Uint8List imageBytes, Uri golden) async {
    final captureDirectory =
        Platform.environment['READFLEX_VISUAL_CAPTURE_DIR'];
    if (captureDirectory != null && captureDirectory.isNotEmpty) {
      final segments = golden.pathSegments;
      final start = segments.indexOf('goldens');
      if (start >= 0) {
        final destination = File.fromUri(
          Directory(captureDirectory).uri.resolve(
            segments.skip(start).join('/'),
          ),
        );
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(imageBytes);
      }
    }
  }

  @override
  Future<String> generateFailureOutput(
    ComparisonResult result,
    Uri golden,
    Uri basedir, {
    String key = '',
  }) => super.generateFailureOutput(
    result,
    golden,
    Directory.current.uri
        .resolve('.local/ui-goldens/${golden.path}')
        .resolve('./'),
    key: key,
  );
}
