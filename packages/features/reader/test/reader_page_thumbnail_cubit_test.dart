import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_page_thumbnail_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'serializes and coalesces requests; released queued tiles never load',
    () async {
      final calls = <int>[];
      final first = Completer<ImageProvider?>();
      final cubit = ReaderPageThumbnailCubit((page) async {
        calls.add(page);
        return page == 0
            ? first.future
            : MemoryImage(Uint8List.fromList([page]));
      });
      addTearDown(cubit.close);
      cubit.request(0);
      cubit.request(0);
      cubit.request(1);
      cubit.request(2);
      cubit.release(1);
      expect(calls, [0]);
      final finished = cubit.stream.firstWhere((s) => s.containsKey(2));
      first.complete(MemoryImage(Uint8List.fromList([0])));
      await finished;
      expect(calls, [0, 2]);
      cubit.request(0);
      expect(calls, [0, 2]);
    },
  );

  test('cache and emitted snapshots remain bounded after 500 pages', () async {
    final cubit = ReaderPageThumbnailCubit(
      (page) async => MemoryImage(Uint8List.fromList([page % 256])),
    );
    addTearDown(cubit.close);
    for (var page = 0; page < 500; page++) {
      final loaded = cubit.stream.firstWhere((s) => s.containsKey(page));
      cubit.request(page);
      await loaded;
      cubit.release(page);
      expect(
        cubit.state.length,
        lessThanOrEqualTo(ReaderPageThumbnailCubit.cacheCapacity),
      );
    }
    expect(cubit.state.keys.first, 476);
  });

  test(
    'one released highlight does not cancel another on the same page',
    () async {
      final pending = Completer<ImageProvider?>();
      var calls = 0;
      final cubit = ReaderPageThumbnailCubit((_) {
        calls++;
        return pending.future;
      });
      addTearDown(cubit.close);
      cubit.request(3);
      cubit.request(3);
      cubit.release(3);
      pending.complete(MemoryImage(Uint8List.fromList([3])));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state[3], isNotNull);
      expect(calls, 1);
      cubit.release(3);
    },
  );

  test('retry does not retain a released thumbnail consumer', () async {
    final pending = Completer<ImageProvider?>();
    var calls = 0;
    final cubit = ReaderPageThumbnailCubit((_) async {
      return ++calls == 1 ? null : pending.future;
    });
    addTearDown(cubit.close);
    cubit.request(2);
    await Future<void>.delayed(Duration.zero);
    cubit.retry(2);
    cubit.release(2);
    pending.complete(MemoryImage(Uint8List.fromList([2])));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.containsKey(2), isFalse);
  });

  test('close cancels the queue and ignores in-flight completion', () async {
    final calls = <int>[];
    final pending = Completer<ImageProvider?>();
    final cubit = ReaderPageThumbnailCubit((page) {
      calls.add(page);
      return pending.future;
    });
    cubit.request(0);
    cubit.request(1);
    await cubit.close();
    pending.complete(MemoryImage(Uint8List.fromList([1])));
    await Future<void>.delayed(Duration.zero);
    expect(calls, [0]);
    expect(cubit.state, isEmpty);
  });

  test('failed previews are local and explicitly retryable', () async {
    {
      var calls = 0;
      final cubit = ReaderPageThumbnailCubit(
        (_) async => ++calls == 1 ? null : MemoryImage(Uint8List.fromList([1])),
      );
      addTearDown(cubit.close);
      final failed = cubit.stream.firstWhere((s) => s.containsKey(2));
      cubit.request(2);
      await failed;
      expect(cubit.state[2], isNull);
      final loaded = cubit.stream.firstWhere((s) => s[2] != null);
      cubit.retry(2);
      await loaded;
      expect(calls, 2);
    }
  });
}
