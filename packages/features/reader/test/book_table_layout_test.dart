import 'dart:convert';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/book_custom_css.dart';

void main() {
  for (final browser in ['chromium', 'webkit']) {
    test(
      'book tables retain readable widths and scrolling in $browser',
      () async {
        final result = await Process.run(
          'node',
          ['--test', 'test_browser/book_tables.test.mjs'],
          environment: {
            'READER_BROWSER': browser,
            // Exercise the actual Flutter-generated overlay, not a CSS copy.
            'READFLEX_TABLE_TEST_CSS': jsonEncode({
              for (final preset in [
                ReaderThemePreset.paper,
                ReaderThemePreset.night,
              ])
                preset.name: buildBookCustomCSS(theme: preset.data),
            }),
          },
        );
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
