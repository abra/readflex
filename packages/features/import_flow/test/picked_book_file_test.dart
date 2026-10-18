import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:import_flow/src/picked_book_file.dart'
    show deletePickedBookFileWithin;
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory temporary;
  late Directory documents;
  late _CollectingLogObserver logs;
  late Logger logger;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('picked_book_file_test_');
    temporary = await Directory(p.join(sandbox.path, 'cache')).create();
    documents = await Directory(p.join(sandbox.path, 'Documents')).create();
    logs = _CollectingLogObserver();
    logger = Logger(observers: [logs]);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await sandbox.delete(recursive: true);
  });

  Future<File> writeFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('book bytes');
    return file;
  }

  Future<void> deleteWithin(File file, {List<Directory>? roots}) =>
      deletePickedBookFileWithin(
        file,
        temporaryDirectories: () async => roots ?? [temporary],
        logger: logger,
      );

  test('Android: deletes the picker copy and its own pick folder', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final pickerRoot = p.join(temporary.path, 'file_picker');
    final picked = await writeFile(
      p.join(pickerRoot, '1760000000000', 'Long Comic.cbz'),
    );
    final otherPick = await writeFile(
      p.join(pickerRoot, '1760000000001', 'Other.epub'),
    );

    await deleteWithin(picked);

    expect(await picked.exists(), isFalse);
    expect(await picked.parent.exists(), isFalse);
    expect(await Directory(pickerRoot).exists(), isTrue);
    expect(await otherPick.exists(), isTrue);
    expect(logs.messages, isEmpty);
  });

  test('iOS: deletes the picked file and leaves the rest of tmp', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final picked = await writeFile(p.join(temporary.path, 'Book.epub'));
    final unrelated = await writeFile(p.join(temporary.path, 'other.tmp'));

    await deleteWithin(picked);

    expect(await picked.exists(), isFalse);
    expect(await temporary.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
    expect(logs.messages, isEmpty);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform: never deletes a file outside temp and cache', () async {
      debugDefaultTargetPlatformOverride = platform;
      final original = await writeFile(p.join(documents.path, 'Book.epub'));

      await deleteWithin(original);

      expect(await original.exists(), isTrue);
      expect(logs.messages, isEmpty);
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('$platform: keeps the original even inside temp', () async {
      debugDefaultTargetPlatformOverride = platform;
      final original = await writeFile(p.join(temporary.path, 'Book.epub'));
      var lookedUp = false;

      await deletePickedBookFileWithin(
        original,
        temporaryDirectories: () async {
          lookedUp = true;
          return [temporary];
        },
        logger: logger,
      );

      expect(await original.exists(), isTrue);
      expect(lookedUp, isFalse);
    });
  }

  test('matches a temp directory reached through a link', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final linkedTemporary = Link(p.join(sandbox.path, 'linked-tmp'));
    await linkedTemporary.create(temporary.path);
    final picked = await writeFile(p.join(temporary.path, 'Book.epub'));

    await deleteWithin(picked, roots: [Directory(linkedTemporary.path)]);

    expect(await picked.exists(), isFalse);
    expect(await linkedTemporary.exists(), isTrue);
    expect(logs.messages, isEmpty);
  });

  test('matches a picked path reported through a linked folder', () async {
    // iOS reports one container as /var/... and /private/var/....
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final linkedTemporary = Link(p.join(sandbox.path, 'linked-tmp'));
    await linkedTemporary.create(temporary.path);
    final real = await writeFile(p.join(temporary.path, 'Book.epub'));
    final reported = File(p.join(linkedTemporary.path, 'Book.epub'));

    await deleteWithin(reported);

    expect(await real.exists(), isFalse);
    expect(await linkedTemporary.exists(), isTrue);
    expect(await temporary.exists(), isTrue);
  });

  test('a link in temp never deletes the file it points to', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final original = await writeFile(p.join(documents.path, 'Book.epub'));
    final link = Link(p.join(temporary.path, 'file_picker', '1', 'Book.epub'));
    await link.create(original.path, recursive: true);

    await deleteWithin(File(link.path));

    expect(await original.exists(), isTrue);
    expect(await link.exists(), isTrue);
    expect(logs.messages, isEmpty);
  });

  test('a link outside temp is kept; only its temp target goes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final copy = await writeFile(p.join(temporary.path, 'Book.epub'));
    final link = Link(p.join(documents.path, 'Book.epub'));
    await link.create(copy.path);

    await deleteWithin(File(link.path));

    expect(await copy.exists(), isFalse);
    expect(
      await FileSystemEntity.type(link.path, followLinks: false),
      FileSystemEntityType.link,
    );
  });

  test('a path that climbs out of temp is not deleted', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final original = await writeFile(p.join(documents.path, 'Book.epub'));

    await deleteWithin(
      File(p.join(temporary.path, '..', 'Documents', 'Book.epub')),
    );

    expect(await original.exists(), isTrue);
  });

  test('keeps a pick folder that still holds other files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final folder = p.join(temporary.path, 'file_picker', '1760000000000');
    final picked = await writeFile(p.join(folder, 'Book.epub'));
    final sibling = await writeFile(p.join(folder, 'Sibling.epub'));

    await deleteWithin(picked);

    expect(await picked.exists(), isFalse);
    expect(await sibling.exists(), isTrue);
    expect(logs.messages, isEmpty);
  });

  test('keeps folders that are not a picker pick folder', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final nested = await writeFile(
      p.join(temporary.path, 'other', '1760000000000', 'Book.epub'),
    );
    final direct = await writeFile(p.join(temporary.path, 'Direct.epub'));

    await deleteWithin(nested);
    await deleteWithin(direct);

    expect(await nested.exists(), isFalse);
    expect(await nested.parent.exists(), isTrue);
    expect(await direct.exists(), isFalse);
    expect(await temporary.exists(), isTrue);
  });

  test('checks every temp directory and skips missing ones', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final cache = await Directory(p.join(sandbox.path, 'second')).create();
    final picked = await writeFile(p.join(cache.path, 'Book.epub'));

    await deleteWithin(
      picked,
      roots: [Directory(p.join(sandbox.path, 'missing')), temporary, cache],
    );

    expect(await picked.exists(), isFalse);
    expect(logs.messages, isEmpty);
  });

  test('a missing picked file is ignored without a warning', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await deleteWithin(File(p.join(temporary.path, 'Gone.epub')));

    expect(logs.messages, isEmpty);
  });

  test(
    'a failed delete is logged and does not throw',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final folder = p.join(temporary.path, 'file_picker', '1760000000000');
      final picked = await writeFile(p.join(folder, 'Book.epub'));
      await _chmod('555', folder);
      try {
        await deleteWithin(picked);
      } finally {
        await _chmod('755', folder);
      }

      expect(await picked.exists(), isTrue);
      expect(logs.messages, hasLength(1));
      expect(logs.messages.single.level, LogLevel.warn);
      expect(logs.messages.single.error, isA<FileSystemException>());
    },
    skip: Platform.isWindows ? 'POSIX permissions only' : false,
  );

  test('a failed directory lookup is logged and does not throw', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final picked = await writeFile(p.join(temporary.path, 'Book.epub'));

    await deletePickedBookFileWithin(
      picked,
      temporaryDirectories: () async => throw StateError('no directory'),
      logger: logger,
    );

    expect(await picked.exists(), isTrue);
    expect(logs.messages.single.error, isA<StateError>());
  });

  group('deletePickedBookFile', () {
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
    });

    test('deletes a picker copy from the platform temp directory', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            expect(call.method, 'getTemporaryDirectory');
            return temporary.path;
          });
      final picked = await writeFile(
        p.join(temporary.path, 'file_picker', '1760000000000', 'Book.epub'),
      );

      await deletePickedBookFile(picked, logger: logger);

      expect(await picked.exists(), isFalse);
      expect(await picked.parent.exists(), isFalse);
      expect(logs.messages, isEmpty);
    });

    test('logs instead of throwing when path_provider is missing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final picked = await writeFile(p.join(temporary.path, 'Book.epub'));

      await expectLater(
        deletePickedBookFile(picked, logger: logger),
        completes,
      );

      expect(await picked.exists(), isTrue);
      expect(logs.messages.single.level, LogLevel.warn);
      expect(logs.messages.single.error, isA<MissingPluginException>());
    });
  });
}

Future<void> _chmod(String mode, String path) async {
  final result = await Process.run('chmod', [mode, path]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

final class _CollectingLogObserver with LogObserver {
  final messages = <LogMessage>[];

  @override
  void onLog(LogMessage logMessage) {
    messages.add(logMessage);
  }
}
