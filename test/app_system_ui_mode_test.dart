import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
