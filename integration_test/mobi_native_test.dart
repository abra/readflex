import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagecraft/mobi.dart';

import '../packages/pagecraft/test/formats/mobi/mobi_fixture_books.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled Rust reads MOBI 6 and lazy KF8 on the device', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('PAGECRAFT_MOBI_USE_DART'), isFalse);
    final report = await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'pagecraft-mobi-device-',
      );
      final entries = <Map<String, Object>>[];
      try {
        for (final kf8 in [false, true]) {
          final path = '${directory.path}/${kf8 ? 'eight.azw3' : 'six.mobi'}';
          await File(path).writeAsBytes(
            kf8 ? MobiFixtureBooks.kf8() : MobiFixtureBooks.mobi6(),
          );
          final timer = Stopwatch()..start();
          final opened = await MobiBook.open(path);
          try {
            if (opened is MobiKf8) {
              expect(
                await opened.book.loadText(0),
                contains(MobiFixtureBooks.fragment1),
              );
              expect(
                await opened.book.loadText(1),
                contains(MobiFixtureBooks.fragment3),
              );
              expect(
                await opened.book.loadText(0),
                contains(MobiFixtureBooks.fragment2),
              );
            } else {
              final book = (opened as MobiLegacy).book;
              expect(book.sections, hasLength(4));
              expect(book.loadText(2), contains('First chapter text'));
              expect(book.loadText(3), contains('Second chapter'));
            }
            timer.stop();
            entries.add({
              'format': kf8 ? 'kf8' : 'mobi6',
              'openAndReadUs': timer.elapsedMicroseconds,
              'maxRssBytes': ProcessInfo.maxRss,
            });
          } finally {
            await opened.close();
            await opened.close();
          }
        }
      } finally {
        await directory.delete(recursive: true);
      }
      return entries;
    });
    binding.reportData = {...?binding.reportData, 'mobiNative': report};
  });
}
