import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_brightness_cubit.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  const sourceId = 'source-1';
  late PreferencesService preferencesService;
  late ReaderUiCubit uiCubit;
  late ReaderSelectionCubit selectionCubit;
  late ReaderBrightnessCubit brightnessCubit;
  late _FakeScreenControlService screenControlService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    uiCubit = ReaderUiCubit();
    selectionCubit = ReaderSelectionCubit();
    screenControlService = _FakeScreenControlService();
    brightnessCubit = ReaderBrightnessCubit(
      preferencesService: preferencesService,
      screenControlService: screenControlService,
      sourceId: sourceId,
    );
  });

  tearDown(() async {
    await uiCubit.close();
    await selectionCubit.close();
    await brightnessCubit.close();
  });

  testWidgets(
    'brightness chrome hides while text selection actions are visible',
    (
      tester,
    ) async {
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
      );

      expect(tester.brightnessIgnorePointer.ignoring, isTrue);

      uiCubit.showChrome();
      await tester.pumpAndSettle();

      expect(tester.brightnessIgnorePointer.ignoring, isFalse);
      expect(find.text('System'), findsOneWidget);
      expect(find.byIcon(AppIcons.deviceMode), findsNothing);
      expect(find.byIcon(AppIcons.lightMode), findsOneWidget);
      expect(find.byIcon(AppIcons.brightnessLow), findsOneWidget);
      expect(find.byIcon(AppIcons.darkMode), findsNothing);

      selectionCubit.select(text: 'Selected text');
      await tester.pumpAndSettle();

      expect(tester.brightnessIgnorePointer.ignoring, isTrue);
    },
  );

  testWidgets('center label clears custom brightness override', (tester) async {
    await tester.pumpBrightnessChrome(
      uiCubit: uiCubit,
      selectionCubit: selectionCubit,
      brightnessCubit: brightnessCubit,
    );

    uiCubit.showChrome();
    brightnessCubit.previewBrightness(0.5);
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsOneWidget);
    expect(brightnessCubit.state.usesSystemBrightness, isFalse);

    await tester.tap(find.text('50%'));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(brightnessCubit.state.usesSystemBrightness, isTrue);
    expect(preferencesService.readerBrightness, isNull);
  });

  testWidgets(
    'brightness buttons adjust custom override from system brightness',
    (
      tester,
    ) async {
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
      );

      brightnessCubit.activate();
      await tester.pump();
      uiCubit.showChrome();
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);

      await tester.tap(find.byTooltip('Increase brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('45%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.45, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.45, 0.001));

      await tester.tap(find.byTooltip('Decrease brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('40%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.4, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.4, 0.001));
    },
  );

  testWidgets(
    'brightness buttons decrease from low platform brightness',
    (tester) async {
      screenControlService.brightness = _controlToPlatform(0.29);
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
      );

      brightnessCubit.activate();
      await tester.pump();
      uiCubit.showChrome();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Decrease brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('25%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.25, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.25, 0.001));
    },
  );

  testWidgets(
    'brightness buttons increase from very low non-grid platform brightness',
    (tester) async {
      screenControlService.brightness = _controlToPlatform(0.125);
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
      );

      brightnessCubit.activate();
      await tester.pump();
      uiCubit.showChrome();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Increase brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('15%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.15, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.15, 0.001));
    },
  );

  testWidgets(
    'brightness buttons snap non-grid system brightness to five percent steps',
    (tester) async {
      screenControlService.brightness = _controlToPlatform(0.68);
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
      );

      brightnessCubit.activate();
      await tester.pump();
      uiCubit.showChrome();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Decrease brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('65%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.65, 0.001));

      await tester.tap(find.text('65%'));
      await tester.pumpAndSettle();

      expect(brightnessCubit.state.usesSystemBrightness, isTrue);
      expect(brightnessCubit.state.systemBrightness, closeTo(0.68, 0.001));

      await tester.tap(find.byTooltip('Increase brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('70%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.7, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.7, 0.001));
    },
  );

  testWidgets(
    'rapid brightness button taps use latest cubit state',
    (tester) async {
      screenControlService.brightness = _controlToPlatform(0.29);
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
      );

      brightnessCubit.activate();
      await tester.pump();
      uiCubit.showChrome();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Decrease brightness'));
      await tester.tap(find.byTooltip('Increase brightness'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('30%'), findsOneWidget);
      expect(brightnessCubit.state.brightnessOverride, closeTo(0.3, 0.001));
      expect(preferencesService.readerBrightness, closeTo(0.3, 0.001));
    },
  );

  testWidgets('dragging brightness chrome previews session override', (
    tester,
  ) async {
    await tester.pumpBrightnessChrome(
      uiCubit: uiCubit,
      selectionCubit: selectionCubit,
      brightnessCubit: brightnessCubit,
    );

    brightnessCubit.activate();
    await tester.pump();
    uiCubit.showChrome();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('readerBrightnessChromeDragArea')),
      const Offset(0, -40),
    );
    await tester.pump();

    expect(brightnessCubit.state.usesSystemBrightness, isFalse);
    expect(brightnessCubit.state.brightnessOverride, greaterThan(0.4));

    await tester.pump(const Duration(milliseconds: 250));

    expect(preferencesService.readerBrightness, greaterThan(0.4));
  });
}

extension on WidgetTester {
  Future<void> pumpBrightnessChrome({
    required ReaderUiCubit uiCubit,
    required ReaderSelectionCubit selectionCubit,
    required ReaderBrightnessCubit brightnessCubit,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: uiCubit),
            BlocProvider.value(value: selectionCubit),
            BlocProvider.value(value: brightnessCubit),
          ],
          child: const Scaffold(
            body: SizedBox.expand(
              child: Stack(
                children: [
                  ReaderBrightnessChromeDriver(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IgnorePointer get brightnessIgnorePointer {
    return widget<IgnorePointer>(
      find.byKey(const ValueKey('readerBrightnessChromeIgnorePointer')),
    );
  }
}

double _controlToPlatform(double value) =>
    value.clamp(ReaderBrightnessCubit.minBrightness, 1.0).toDouble();

class _FakeScreenControlService implements ScreenControlService {
  double? brightness = _controlToPlatform(0.4);
  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}

  @override
  Future<double?> readApplicationBrightness() async => brightness;

  @override
  Future<void> setApplicationBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationBrightness() async {}
}
