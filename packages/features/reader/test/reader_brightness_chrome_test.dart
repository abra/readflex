import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
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
  double? systemBrightness = _controlToPlatform(0.4);
  double? appBrightnessOverride;

  double? get brightness => appBrightnessOverride ?? systemBrightness;

  set brightness(double? value) {
    systemBrightness = value;
    appBrightnessOverride = null;
  }

  @override
  Future<void> keepAwake() => SynchronousFuture<void>(null);

  @override
  Future<void> allowSleep() => SynchronousFuture<void>(null);

  @override
  Future<double?> readApplicationBrightness() =>
      SynchronousFuture<double?>(brightness);

  @override
  Future<void> setApplicationBrightness(double brightness) {
    appBrightnessOverride = brightness;
    return SynchronousFuture<void>(null);
  }

  @override
  Future<void> resetApplicationBrightness() {
    appBrightnessOverride = null;
    return SynchronousFuture<void>(null);
  }
}
