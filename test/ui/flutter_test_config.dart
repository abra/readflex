import 'dart:async';
import 'dart:io';

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
