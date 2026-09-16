import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';
import 'package:reader_server/reader_server.dart';
import 'package:readflex/app/app_lifecycle.dart';
import 'package:readflex/app/resource_disposer.dart';

import '../support/app_fakes.dart';

void main() {
  testWidgets(
    'overlapping resumes share restart; detach waits before closing',
    (tester) async {
      final dependencies = _Dependencies();
      final completion = Completer<void>();
      dependencies.readerServer.startCompletion = completion;
      await tester.pumpWidget(
        AppLifecycle(
          dependencies: dependencies,
          child: const SizedBox.shrink(),
        ),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }
      expect(dependencies.readerServer.starts, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(dependencies.disposals, 0);
      completion.complete();
      await tester.pump();
      expect(dependencies.disposals, 1);
      expect(dependencies.readerServer.running, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(dependencies.readerServer.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'resume and disposal policy on $platform',
      (tester) async {
        final dependencies = _Dependencies();
        await tester.pumpWidget(
          AppLifecycle(
            dependencies: dependencies,
            child: const SizedBox.shrink(),
          ),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(dependencies.disposals, 0);
        expect(dependencies.readerServer.starts, 0);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          dependencies.readerServer.starts,
          platform == TargetPlatform.iOS ? 1 : 0,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          dependencies.readerServer.starts,
          platform == TargetPlatform.iOS ? 1 : 0,
          reason: 'A running server must not restart',
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.detached,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.detached,
        );
        await tester.pump();
        expect(dependencies.disposals, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          dependencies.readerServer.starts,
          platform == TargetPlatform.iOS ? 1 : 0,
          reason:
              'The disposed observer must no longer handle lifecycle events',
        );
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'server restart failure is reported without escaping lifecycle callback',
    (tester) async {
      final sink = _LogSink();
      final dependencies = _Dependencies();
      dependencies.logger.addObserver(sink);
      dependencies.readerServer.fail = true;
      await tester.pumpWidget(
        AppLifecycle(
          dependencies: dependencies,
          child: const SizedBox.shrink(),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(sink.messages.single.error, isStateError);
      expect(sink.messages.single.level, LogLevel.error);
      expect(dependencies.disposals, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        dependencies.disposals,
        0,
        reason: 'Unmounting is not ownership disposal',
      );
      await dependencies.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}

final class _Dependencies extends TestDependenciesContainer {
  final _logger = Logger();
  final _server = _ReaderServer();
  @override
  Logger get logger => _logger;
  @override
  _ReaderServer get readerServer => _server;
  int disposals = 0;
  late final _resources = ResourceDisposer(logger: logger)
    ..add('runtime', () {
      disposals++;
    })
    ..add('server', readerServer.stop);
  @override
  Future<void> dispose() => _resources.dispose();
}

class _ReaderServer extends ReaderServer {
  _ReaderServer()
    : super(
        assetsDirectory: Directory('unused-assets'),
        booksDirectory: Directory('unused-books'),
        articlesDirectory: Directory('unused-articles'),
        logger: Logger(),
      );
  int starts = 0;
  bool running = false;
  bool fail = false;
  Completer<void>? startCompletion;
  @override
  bool get isRunning => running;
  @override
  Future<void> start() async {
    starts++;
    await startCompletion?.future;
    if (fail) throw StateError('Cannot bind reader server');
    running = true;
  }

  @override
  Future<void> stop() async {
    running = false;
  }
}

class _LogSink with LogObserver {
  final messages = <LogMessage>[];
  @override
  void onLog(LogMessage logMessage) => messages.add(logMessage);
}
