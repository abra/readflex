import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_brightness_cubit.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  const sourceId = 'source-1';
  const otherSourceId = 'source-2';
  late PreferencesService preferencesService;
  late _FakeScreenControlService screenControlService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    screenControlService = _FakeScreenControlService();
  });

  ReaderBrightnessCubit buildCubit({String id = sourceId}) =>
      ReaderBrightnessCubit(
        preferencesService: preferencesService,
        screenControlService: screenControlService,
        sourceId: id,
      );

  test('activate resets application brightness in system mode', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.usesSystemBrightness, isTrue);
    expect(cubit.state.systemBrightness, closeTo(0.4, 0.001));
    expect(cubit.state.sliderValue, closeTo(0.4, 0.001));
    expect(preferencesService.readerBrightness, isNull);
    expect(screenControlService.calls, const ['resetBrightness']);
  });

  test(
    'preview applies custom brightness and commit stores it globally',
    () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.activate();
      await Future<void>.delayed(Duration.zero);

      cubit.previewBrightness(0.6);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.brightnessOverride, 0.6);
      expect(preferencesService.readerBrightness, isNull);
      expect(screenControlService.calls, [
        'resetBrightness',
        'set:${_controlToPlatform(0.6).toStringAsFixed(2)}',
      ]);

      cubit.commitBrightness(0.6);
      await Future<void>.delayed(Duration.zero);

      expect(preferencesService.readerBrightness, 0.6);
      expect(preferencesService.readerLastCustomBrightness, 0.6);
      expect(preferencesService.readerBrightnessOverrideFor(sourceId), isNull);
      expect(
        preferencesService.readerBrightnessOverrideFor(otherSourceId),
        isNull,
      );
    },
  );

  test(
    'useSystemBrightness clears global custom value and resets platform',
    () async {
      await preferencesService.setReaderBrightness(0.55);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.activate();
      await Future<void>.delayed(Duration.zero);
      await cubit.useSystemBrightness();

      expect(cubit.state.usesSystemBrightness, isTrue);
      expect(preferencesService.readerBrightness, isNull);
      expect(preferencesService.readerLastCustomBrightness, 0.55);
      expect(screenControlService.calls, const ['set:0.55', 'resetBrightness']);
    },
  );

  test('stored global brightness is applied on activate', () async {
    await preferencesService.setReaderBrightness(0.55);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.usesSystemBrightness, isFalse);
    expect(cubit.state.brightnessOverride, 0.55);
    expect(cubit.state.controlValue, 0.55);
    expect(screenControlService.calls, const ['set:0.55']);
  });

  test(
    'legacy per-source brightness is ignored and cleared on activate',
    () async {
      await preferencesService.setReaderBrightnessOverride(sourceId, 0.12);
      await preferencesService.setReaderBrightnessOverride(otherSourceId, 0.8);
      screenControlService.brightness = _controlToPlatform(0.5);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.activate();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.usesSystemBrightness, isTrue);
      expect(cubit.state.systemBrightness, closeTo(0.5, 0.001));
      expect(cubit.state.controlValue, closeTo(0.5, 0.001));
      expect(preferencesService.readerBrightnessOverrideFor(sourceId), isNull);
      expect(
        preferencesService.readerBrightnessOverrideFor(otherSourceId),
        0.8,
      );
      expect(screenControlService.calls, const ['resetBrightness']);
    },
  );

  test('clearing brightness preserves other appearance overrides', () async {
    await preferencesService.setReaderAppearanceOverride(
      sourceId,
      const ReaderAppearanceOverride(
        fontId: 'sans',
        brightnessOverride: 0.5,
      ),
    );
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.useSystemBrightness();

    final override = preferencesService.readerAppearanceOverrideFor(sourceId);
    expect(override?.fontId, 'sans');
    expect(override?.brightnessOverride, isNull);
  });

  test('deactivate resets platform but preserves saved custom value', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);
    cubit.previewBrightness(0.45);
    cubit.commitBrightness(0.45);
    await Future<void>.delayed(Duration.zero);
    await cubit.deactivate();

    expect(cubit.state.usesSystemBrightness, isFalse);
    expect(cubit.state.brightnessOverride, closeTo(0.45, 0.001));
    expect(preferencesService.readerBrightness, closeTo(0.45, 0.001));
    expect(screenControlService.calls, [
      'resetBrightness',
      'set:${_controlToPlatform(0.45).toStringAsFixed(2)}',
      'resetBrightness',
    ]);
  });

  test('reactivate in system mode reads the new platform brightness', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);
    await cubit.deactivate();

    screenControlService.brightness = 1.0;
    cubit.activate();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.usesSystemBrightness, isTrue);
    expect(cubit.state.systemBrightness, 1.0);
    expect(cubit.state.controlValue, 1.0);
    expect(
      screenControlService.calls,
      const ['resetBrightness', 'resetBrightness', 'resetBrightness'],
    );
  });

  test('first custom step can start from captured system brightness', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.usesSystemBrightness, isTrue);
    expect(cubit.state.sliderValue, closeTo(0.4, 0.001));

    cubit.previewBrightness(cubit.state.sliderValue + 0.05);
    cubit.commitBrightness(cubit.state.sliderValue);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.brightnessOverride, closeTo(0.45, 0.001));
    expect(preferencesService.readerBrightness, closeTo(0.45, 0.001));
  });

  test(
    'first custom step falls back to last custom when platform is unavailable',
    () async {
      await preferencesService.setReaderBrightness(0.6);
      await preferencesService.setReaderBrightness(null);
      screenControlService.brightness = null;
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.activate();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.usesSystemBrightness, isTrue);
      expect(cubit.state.systemBrightness, isNull);
      expect(cubit.state.sliderValue, 0.6);

      cubit.previewBrightness(cubit.state.sliderValue - 0.05);
      cubit.commitBrightness(cubit.state.sliderValue);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.brightnessOverride, closeTo(0.55, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.55, 0.001));
    },
  );

  test(
    'manual controls use low platform brightness as current value',
    () async {
      screenControlService.brightness = _controlToPlatform(0.29);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.activate();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.usesSystemBrightness, isTrue);
      expect(cubit.state.systemBrightness, closeTo(0.29, 0.001));
      expect(cubit.state.sliderValue, closeTo(0.29, 0.001));
      expect(cubit.state.controlValue, closeTo(0.29, 0.001));

      cubit.previewBrightness(cubit.state.controlValue - 0.05);
      cubit.commitBrightness(cubit.state.controlValue);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.brightnessOverride, closeTo(0.24, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.24, 0.001));
    },
  );
}

double _controlToPlatform(double value) =>
    value.clamp(ReaderBrightnessCubit.minBrightness, 1.0).toDouble();

class _FakeScreenControlService implements ScreenControlService {
  final List<String> calls = [];
  final List<double> writes = [];
  double? brightness = _controlToPlatform(0.4);

  @override
  Future<void> keepAwake() async {
    calls.add('keepAwake');
  }

  @override
  Future<void> allowSleep() async {
    calls.add('allowSleep');
  }

  @override
  Future<double?> readApplicationBrightness() async => brightness;

  @override
  Future<void> setApplicationBrightness(double brightness) async {
    writes.add(brightness);
    calls.add('set:${brightness.toStringAsFixed(2)}');
  }

  @override
  Future<void> resetApplicationBrightness() async {
    calls.add('resetBrightness');
  }
}
