import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/dictionary');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('normalizes the term and returns platform result', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return true;
        });
    const service = PlatformSystemDictionaryService(channel: channel);

    expect(await service.showDefinition('  power  '), isTrue);
    expect(captured?.method, 'showDefinition');
    expect(captured?.arguments, {'term': 'power'});
  });

  test('returns false when the platform bridge is unavailable', () async {
    const service = PlatformSystemDictionaryService(channel: channel);

    expect(await service.showDefinition('power'), isFalse);
    expect(await service.showDefinition('   '), isFalse);
  });
}
