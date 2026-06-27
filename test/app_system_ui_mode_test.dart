import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/app_system_ui_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSystemUiMode', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('keeps top and bottom system overlays visible', (
      tester,
    ) async {
      await tester.pumpWidget(const AppSystemUiMode(child: SizedBox()));

      expect(
        calls.map((call) => call.method),
        containsAllInOrder([
          'SystemChrome.setEnabledSystemUIOverlays',
          'SystemChrome.setSystemUIChangeListener',
        ]),
      );
      expect(calls.first.arguments, [
        'SystemUiOverlay.top',
        'SystemUiOverlay.bottom',
      ]);
    });

    testWidgets('lets descendants hide and restore the bottom overlay', (
      tester,
    ) async {
      AppSystemUiModeController? controller;

      await tester.pumpWidget(
        AppSystemUiMode(
          child: Builder(
            builder: (context) {
              controller = AppSystemUiMode.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      calls.clear();
      await controller!.hideBottomSystemOverlay();

      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.single.arguments, ['SystemUiOverlay.top']);

      calls.clear();
      await controller!.showBottomSystemOverlay();

      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.single.arguments, [
        'SystemUiOverlay.top',
        'SystemUiOverlay.bottom',
      ]);
    });

    testWidgets('reapplies a hidden bottom overlay when requested again', (
      tester,
    ) async {
      AppSystemUiModeController? controller;

      await tester.pumpWidget(
        AppSystemUiMode(
          child: Builder(
            builder: (context) {
              controller = AppSystemUiMode.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      await controller!.hideBottomSystemOverlay();

      calls.clear();
      await controller!.hideBottomSystemOverlay();

      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.single.arguments, ['SystemUiOverlay.top']);
    });

    testWidgets('restores a hidden bottom overlay when route pop starts', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        AppSystemUiMode(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const SizedBox(),
          ),
        ),
      );

      calls.clear();
      unawaited(
        navigatorKey.currentState!.push<void>(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 100),
            reverseTransitionDuration: const Duration(milliseconds: 100),
            pageBuilder: (context, animation, secondaryAnimation) {
              return const AppBottomSystemOverlayVisibility(
                visible: false,
                child: SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_hasOverlayCall(calls, ['SystemUiOverlay.top']), isTrue);

      calls.clear();
      navigatorKey.currentState!.pop();
      await tester.pump();

      expect(
        _hasOverlayCall(calls, [
          'SystemUiOverlay.top',
          'SystemUiOverlay.bottom',
        ]),
        isTrue,
      );
    });

    testWidgets('does not restore overlays when disposed', (
      tester,
    ) async {
      await tester.pumpWidget(const AppSystemUiMode(child: SizedBox()));
      await tester.pumpWidget(const SizedBox());

      expect(
        calls.map((call) => call.method),
        isNot(contains('SystemChrome.restoreSystemUIOverlays')),
      );
    });
  });
}

bool _hasOverlayCall(List<MethodCall> calls, List<String> overlays) {
  return calls.any((call) {
    if (call.method != 'SystemChrome.setEnabledSystemUIOverlays') {
      return false;
    }
    final arguments = call.arguments;
    if (arguments is! List<Object?> || arguments.length != overlays.length) {
      return false;
    }
    for (var i = 0; i < overlays.length; i += 1) {
      if (arguments[i] != overlays[i]) return false;
    }
    return true;
  });
}
