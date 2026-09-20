import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'extracts the bundled symbol font for the local reader server',
    () async {
      const bundleKey =
          'packages/component_library/fonts/NotoSansSymbols-Regular.ttf';
      final bytes = Uint8List.fromList([0, 1, 0, 0, 42]);
      final requested = <String>[];
      final directory = await Directory.systemTemp.createTemp('reader-assets-');
      addTearDown(() => directory.delete(recursive: true));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        requested.add(key);
        return ByteData.sublistView(bytes);
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      rootBundle.evict(bundleKey);

      final extractor = AssetExtractor(targetDirectory: directory);
      await extractor.extractAll(version: 'test');
      final font = File('${directory.path}/fonts/NotoSansSymbols-Regular.ttf');
      expect(requested, contains(bundleKey));
      expect(await font.readAsBytes(), bytes);

      requested.clear();
      await extractor.extractAll(version: 'test');
      expect(
        requested,
        isEmpty,
        reason: 'Unchanged assets reuse the disk copy',
      );
    },
  );
}
