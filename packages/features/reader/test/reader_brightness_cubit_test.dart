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
    expect(screenControlService.calls, const ['resetBrightness']);
  });

  test('preview applies custom brightness and commit persists it', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);

    cubit.previewBrightness(0.6);
    cubit.commitBrightness(0.6);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(cubit.state.brightnessOverride, 0.6);
    expect(preferencesService.readerBrightnessOverrideFor(sourceId), 0.6);
    expect(
      preferencesService.readerBrightnessOverrideFor(otherSourceId),
      isNull,
    );
    expect(screenControlService.calls, const ['resetBrightness', 'set:0.60']);
  });

  test('useSystemBrightness clears preference and resets platform', () async {
    await preferencesService.setReaderBrightnessOverride(sourceId, 0.5);
    await preferencesService.setReaderBrightnessOverride(otherSourceId, 0.8);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);
    await cubit.useSystemBrightness();

    expect(cubit.state.usesSystemBrightness, isTrue);
    expect(preferencesService.readerBrightnessOverrideFor(sourceId), isNull);
    expect(preferencesService.readerBrightnessOverrideFor(otherSourceId), 0.8);
    expect(screenControlService.calls, const ['set:0.50', 'resetBrightness']);
  });

  test('source brightness is isolated per book', () async {
    await preferencesService.setReaderBrightnessOverride(sourceId, 0.6);
    await preferencesService.setReaderBrightnessOverride(otherSourceId, 0.8);

    final cubit = buildCubit();
    final otherCubit = buildCubit(id: otherSourceId);
    addTearDown(cubit.close);
    addTearDown(otherCubit.close);

    expect(cubit.state.brightnessOverride, 0.6);
    expect(otherCubit.state.brightnessOverride, 0.8);
  });

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

  test('deactivate resets and activate reapplies custom brightness', () async {
    await preferencesService.setReaderBrightnessOverride(sourceId, 0.4);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.activate();
    await Future<void>.delayed(Duration.zero);
    await cubit.deactivate();
    cubit.activate();
    await Future<void>.delayed(Duration.zero);

    expect(
      screenControlService.calls,
      const ['set:0.40', 'resetBrightness', 'set:0.40'],
    );
  });
}

class _FakeScreenControlService implements ScreenControlService {
  final List<String> calls = [];

  @override
  Future<void> keepAwake() async {
    calls.add('keepAwake');
  }

  @override
  Future<void> allowSleep() async {
    calls.add('allowSleep');
  }

  @override
  Future<void> setApplicationBrightness(double brightness) async {
    calls.add('set:${brightness.toStringAsFixed(2)}');
  }

  @override
  Future<void> resetApplicationBrightness() async {
    calls.add('resetBrightness');
  }
}
