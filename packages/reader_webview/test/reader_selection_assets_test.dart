import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles the complete shared selection runtime', () async {
    for (final name in [
      'readflex_selection_start',
      'readflex_selection_handles',
      'readflex_selection_navigation',
      'readflex_article_selection',
    ]) {
      final source = await rootBundle.loadString(
        'packages/reader_webview/assets/foliate-js/src/$name.js',
      );
      expect(source, isNotEmpty, reason: name);
    }
  });
}
