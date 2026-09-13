import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';

import '../test/support/library_workload.dart';

void main() {
  test(
    'measures library derivation and cached reads by collection size',
    () async {
      final measurements = <Map<String, Object>>[];
      for (final count in [1000, 5000, 20000]) {
        final books = libraryWorkload(count);
        final samples = <int>[];
        var cachedReadsUs = 0;
        for (var run = 0; run < 6; run++) {
          final timer = Stopwatch()..start();
          final state = LibraryState(books: books);
          expect(state.visibleItems, hasLength(count));
          final search = state.copyWith(searchQuery: 'Author 23');
          expect(search.visibleItems, hasLength(count ~/ 100));
          timer.stop();
          if (run > 0) samples.add(timer.elapsedMicroseconds);
          final visible = state.visibleItems;
          timer.reset();
          timer.start();
          for (var read = 0; read < 10000; read++) {
            expect(identical(state.visibleItems, visible), isTrue);
          }
          timer.stop();
          cachedReadsUs = timer.elapsedMicroseconds;
        }
        samples.sort();
        measurements.add({
          'sources': count,
          'medianDeriveAndFilterUs': samples[samples.length ~/ 2],
          'samplesUs': samples,
          'cached10000ReadsUs': cachedReadsUs,
        });
      }
      final report = {
        'suite': 'library-derivation',
        'runtime': Platform.version,
        'mode':
            'flutter-test JIT, in-memory models, not SQLite or device frames',
        'measurements': measurements,
      };
      final output = File('.local/performance/library.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      // ignore: avoid_print
      print(jsonEncode(report));
    },
  );
}
