import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('resolveInitialReaderLocation', () {
    test('prefers exact CFI on normal load', () {
      final location = resolveInitialReaderLocation(
        initialCfi: 'epubcfi(/6/14!/4/2)',
        initialProgress: 0.73,
        recoveringFromCrash: false,
      );

      expect(location.cfi, 'epubcfi(/6/14!/4/2)');
      expect(location.progress, isNull);
    });

    test('falls back to progress when CFI is missing', () {
      final location = resolveInitialReaderLocation(
        initialCfi: null,
        initialProgress: 0.73,
        recoveringFromCrash: false,
      );

      expect(location.cfi, isNull);
      expect(location.progress, 0.73);
    });

    test('drops CFI during recovery but keeps progress fallback', () {
      final location = resolveInitialReaderLocation(
        initialCfi: 'epubcfi(/6/14!/4/2)',
        initialProgress: 0.73,
        recoveringFromCrash: true,
      );

      expect(location.cfi, isNull);
      expect(location.progress, 0.73);
    });

    test('rejects non-positive progress fallback', () {
      final location = resolveInitialReaderLocation(
        initialCfi: null,
        initialProgress: 0,
        recoveringFromCrash: false,
      );

      expect(location.cfi, isNull);
      expect(location.progress, isNull);
    });
  });
}
