import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  test(
    'measures search bursts at increasing document sizes',
    () async {
      final measurements = <Map<String, Object>>[];
      for (final count in [1000, 5000, 20000]) {
        final samples = <int>[];
        var emissions = 0;
        var publishedEntries = 0;
        for (var run = 0; run < 4; run++) {
          final cubit = ReaderSearchCubit();
          final finished = Completer<void>();
          emissions = 0;
          publishedEntries = 0;
          final subscription = cubit.stream.listen((state) {
            emissions++;
            publishedEntries += state.results.length;
            if (!state.isLoading && !finished.isCompleted) finished.complete();
          });
          final events = List.generate(
            count,
            (index) => ReaderSearchResults(
              requestId: 1,
              results: [
                ReaderSearchResult(
                  cfi: 'cfi-$index',
                  excerpt: const ReaderSearchExcerpt(match: 'power'),
                ),
              ],
            ),
            growable: false,
          );
          final stopwatch = Stopwatch()..start();
          cubit.recentQuerySelected(
            'power',
            searchBook: (_) => Stream.fromIterable(events),
          );
          await finished.future.timeout(const Duration(seconds: 30));
          stopwatch.stop();
          expect(cubit.state.results, hasLength(count));
          if (run > 0) samples.add(stopwatch.elapsedMicroseconds);
          await subscription.cancel();
          await cubit.close();
        }
        samples.sort();
        measurements.add({
          'results': count,
          'medianMicroseconds': samples[1],
          'samplesMicroseconds': samples,
          'stateEmissions': emissions,
          'publishedResultEntries': publishedEntries,
        });
      }
      final report = {
        'suite': 'reader-search-burst',
        'runtime': Platform.version,
        'mode': 'flutter-test JIT; not device frame timings',
        'warmupRuns': 1,
        'measuredRuns': 3,
        'measurements': measurements,
      };
      const path = String.fromEnvironment(
        'PERF_OUTPUT',
        defaultValue: '.local/performance/reader-search.json',
      );
      final output = File(path);
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      // ignore: avoid_print
      print(jsonEncode(report));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
