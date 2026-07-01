import 'package:device_screen_brightness/device_screen_brightness.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_control_service/screen_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoopScreenControlService', () {
    test('keepAwake completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.keepAwake(), completes);
    });

    test('allowSleep completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.allowSleep(), completes);
    });

    test('setApplicationBrightness completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.setApplicationBrightness(0.4), completes);
    });

    test('readApplicationBrightness returns null', () async {
      const service = NoopScreenControlService();

      await expectLater(
        service.readApplicationBrightness(),
        completion(isNull),
      );
    });

    test('resetApplicationBrightness completes without error', () async {
      const service = NoopScreenControlService();

      await expectLater(service.resetApplicationBrightness(), completes);
    });
  });

  group('WakelockScreenControlService', () {
    test('reads app brightness through device_screen_brightness', () async {
      final deviceBrightness = _FakeDeviceBrightness(initialPercent: 62);
      final service = WakelockScreenControlService(
        readDeviceBrightness: deviceBrightness.read,
        writeDeviceBrightness: deviceBrightness.write,
        brightnessMode: BrightnessMode.app,
        useAndroidNativeAppBrightness: false,
        useAndroidNativeReset: false,
      );

      final brightness = await service.readApplicationBrightness();

      expect(brightness, 0.62);
      expect(deviceBrightness.calls, const ['read:app']);
    });

    test('read returns null when device brightness backend fails', () async {
      final deviceBrightness = _FakeDeviceBrightness(
        initialPercent: 62,
        throwOnRead: true,
      );
      final service = WakelockScreenControlService(
        readDeviceBrightness: deviceBrightness.read,
        writeDeviceBrightness: deviceBrightness.write,
        brightnessMode: BrightnessMode.app,
        useAndroidNativeAppBrightness: false,
        useAndroidNativeReset: false,
      );

      final brightness = await service.readApplicationBrightness();

      expect(brightness, isNull);
      expect(deviceBrightness.calls, const ['read:app']);
    });

    test(
      'sets clamped app brightness through device_screen_brightness',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 40);
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: false,
          useAndroidNativeReset: false,
        );

        await service.setApplicationBrightness(0.654);

        expect(deviceBrightness.calls, const ['read:app', 'write:app:65']);
        expect(deviceBrightness.percent, 65);
      },
    );

    test('read does not capture a reset baseline', () async {
      final deviceBrightness = _FakeDeviceBrightness(initialPercent: 40);
      final service = WakelockScreenControlService(
        readDeviceBrightness: deviceBrightness.read,
        writeDeviceBrightness: deviceBrightness.write,
        brightnessMode: BrightnessMode.app,
        useAndroidNativeAppBrightness: false,
        useAndroidNativeReset: false,
      );

      await service.readApplicationBrightness();
      deviceBrightness.percent = 70;
      await service.resetApplicationBrightness();

      expect(deviceBrightness.calls, const ['read:app']);
      expect(deviceBrightness.percent, 70);
    });

    test(
      'Android app brightness prefers the native Activity channel',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 40);
        const channel = MethodChannel(
          'test.readflex.screen_control.native_app',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final nativeCalls = <String>[];
        var nativeBrightness = 0.52;
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          switch (call.method) {
            case 'readApplicationBrightnessInfo':
              return <String, Object?>{
                'brightness': nativeBrightness,
                'source': 'window',
                'window': nativeBrightness,
                'display': null,
                'float': null,
                'int': 0.4,
                'mode': 'manual',
              };
            case 'setApplicationBrightness':
              final args = call.arguments as Map<Object?, Object?>;
              nativeBrightness = args['brightness']! as double;
              return nativeBrightness;
            default:
              return null;
          }
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: true,
          useAndroidNativeReset: false,
        );

        final brightness = await service.readApplicationBrightness();
        await service.setApplicationBrightness(0.654);

        expect(brightness, 0.52);
        expect(nativeBrightness, 0.654);
        expect(nativeCalls, const [
          'readApplicationBrightnessInfo',
          'readApplicationBrightnessInfo',
          'setApplicationBrightness',
        ]);
        expect(deviceBrightness.calls, isEmpty);
      },
    );

    test(
      'Android app brightness uses native selected value over raw diagnostics',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 13);
        const channel = MethodChannel(
          'test.readflex.screen_control.native_int_range',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'readApplicationBrightnessInfo') return null;
          return <String, Object?>{
            'brightness': 0.5,
            'source': 'intSetting',
            'window': null,
            'display': null,
            'float': null,
            'int': 0.5,
            'intRaw': 32,
            'intMin': 0,
            'intMax': 63,
            'mode': 'manual',
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: true,
          useAndroidNativeReset: false,
        );

        final brightness = await service.readApplicationBrightness();

        expect(brightness, 0.5);
        expect(deviceBrightness.calls, isEmpty);
      },
    );

    test(
      'Android app brightness keeps converted system value in manual mode',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 13);
        const channel = MethodChannel(
          'test.readflex.screen_control.native_manual_divergence',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'readApplicationBrightnessInfo') return null;
          return <String, Object?>{
            'brightness': 0.713,
            'source': 'intSetting',
            'window': null,
            'display': 0.9,
            'float': null,
            'int': 0.713,
            'intRaw': 56,
            'intMin': 8,
            'intMax': 4095,
            'intScaleMin': 0,
            'intScaleMax': 255,
            'mode': 'manual',
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: true,
          useAndroidNativeReset: false,
        );

        final brightness = await service.readApplicationBrightness();

        expect(brightness, 0.713);
        expect(deviceBrightness.calls, isEmpty);
      },
    );

    test(
      'Android app brightness adapts to display value in automatic mode',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 13);
        const channel = MethodChannel(
          'test.readflex.screen_control.native_automatic_divergence',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'readApplicationBrightnessInfo') return null;
          return <String, Object?>{
            'brightness': 0.713,
            'source': 'intSetting',
            'window': null,
            'display': 0.9,
            'float': null,
            'int': 0.713,
            'intRaw': 56,
            'intMin': 8,
            'intMax': 4095,
            'intScaleMin': 0,
            'intScaleMax': 255,
            'mode': 'automatic',
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: true,
          useAndroidNativeReset: false,
        );

        final brightness = await service.readApplicationBrightness();

        expect(brightness, 0.9);
        expect(deviceBrightness.calls, isEmpty);
      },
    );

    test(
      'Android app brightness falls back when native read returns null',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 29);
        const channel = MethodChannel(
          'test.readflex.screen_control.native_null',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readApplicationBrightness') return null;
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: true,
          useAndroidNativeReset: false,
        );

        final brightness = await service.readApplicationBrightness();

        expect(brightness, 0.29);
        expect(deviceBrightness.calls, const ['read:app']);
      },
    );

    test(
      'Android app brightness falls back when native channel is missing',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 40);
        const channel = MethodChannel(
          'test.readflex.screen_control.missing_app',
        );
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: true,
          useAndroidNativeReset: false,
        );

        await service.setApplicationBrightness(0.65);

        expect(deviceBrightness.calls, const ['read:app', 'write:app:65']);
        expect(deviceBrightness.percent, 65);
      },
    );

    test('Android reset prefers native app brightness reset', () async {
      final deviceBrightness = _FakeDeviceBrightness(initialPercent: 40);
      const channel = MethodChannel('test.readflex.screen_control.reset');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final nativeCalls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = WakelockScreenControlService(
        readDeviceBrightness: deviceBrightness.read,
        writeDeviceBrightness: deviceBrightness.write,
        nativeScreenControlChannel: channel,
        brightnessMode: BrightnessMode.app,
        useAndroidNativeAppBrightness: false,
        useAndroidNativeReset: true,
      );

      await service.setApplicationBrightness(0.65);
      await service.resetApplicationBrightness();

      expect(deviceBrightness.calls, const ['read:app', 'write:app:65']);
      expect(nativeCalls, const ['resetApplicationBrightness']);
    });

    test(
      'reset restores captured baseline when native reset is unavailable',
      () async {
        final deviceBrightness = _FakeDeviceBrightness(initialPercent: 40);
        const channel = MethodChannel('test.readflex.screen_control.missing');
        final service = WakelockScreenControlService(
          readDeviceBrightness: deviceBrightness.read,
          writeDeviceBrightness: deviceBrightness.write,
          nativeScreenControlChannel: channel,
          brightnessMode: BrightnessMode.app,
          useAndroidNativeAppBrightness: false,
          useAndroidNativeReset: true,
        );

        await service.setApplicationBrightness(0.65);
        await service.resetApplicationBrightness();

        expect(
          deviceBrightness.calls,
          const ['read:app', 'write:app:65', 'write:app:40'],
        );
        expect(deviceBrightness.percent, 40);
      },
    );
  });
}

class _FakeDeviceBrightness {
  _FakeDeviceBrightness({required int initialPercent, this.throwOnRead = false})
    : percent = initialPercent;

  int percent;
  final bool throwOnRead;
  final List<String> calls = [];

  int read({BrightnessMode mode = BrightnessMode.system}) {
    calls.add('read:${mode.name}');
    if (throwOnRead) {
      throw const NativeBackendException(message: 'fake failure');
    }
    return percent;
  }

  int write(int value, {BrightnessMode mode = BrightnessMode.system}) {
    calls.add('write:${mode.name}:$value');
    percent = value;
    return percent;
  }
}
