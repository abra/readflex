import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
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
      expect(find.text('System'), findsNothing);
      expect(find.byIcon(AppIcons.deviceMode), findsOneWidget);
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

    expect(find.text('System'), findsNothing);
    expect(find.byIcon(AppIcons.deviceMode), findsOneWidget);
    expect(brightnessCubit.state.usesSystemBrightness, isTrue);
    expect(preferencesService.readerBrightness, isNull);
  });
  testWidgets('brightness steps are shared plain icon buttons', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpBrightnessChrome(
      uiCubit: uiCubit,
      selectionCubit: selectionCubit,
      brightnessCubit: brightnessCubit,
    );
    uiCubit.showChrome();
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    for (final tooltip in [
      l10n.readerIncreaseBrightness,
      l10n.readerDecreaseBrightness,
    ]) {
      final button = find.byTooltip(tooltip);
      expect(
        find.ancestor(of: button, matching: find.byType(AppPlainIconButton)),
        findsOneWidget,
      );
      expect(tester.getSize(button), const Size.square(AppSizes.buttonHeight));
      final ink = tester.widget<InkWell>(
        find.descendant(of: button, matching: find.byType(InkWell)),
      );
      expect(ink.customBorder, isA<CircleBorder>());
    }
    final value = tester.getSemantics(
      find.bySemanticsLabel(
        l10n.readerUsingSystemBrightness(l10n.readerBrightnessSystem),
      ),
    );
    expect(value.flagsCollection.isButton, isTrue);
    expect(value.flagsCollection.isEnabled, Tristate.isFalse);
    expect(value.flagsCollection.isSelected, Tristate.isFalse);
    expect(value.rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
    expect(value.rect.width, AppSizes.buttonHeight);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('custom brightness is the selected control dark=$dark', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
        dark: dark,
      );
      uiCubit.showChrome();
      brightnessCubit.previewBrightness(0.5);
      await tester.pumpAndSettle();
      final context = tester.element(find.text('50%'));
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text('50%'), matching: find.byType(Material))
            .first,
      );
      expect(material.color, context.colors.selectedControlBackground);
      expect(
        tester.widget<Text>(find.text('50%')).style?.color,
        context.colors.selectedControlForeground,
      );
      expect(
        tester.widget<Text>(find.text('50%')).style?.color,
        isNot(dark ? context.colors.primary : null),
      );
      final value = tester.getSemantics(
        find.bySemanticsLabel(context.l10n.readerUseSystemBrightness),
      );
      expect(value.flagsCollection.isSelected, Tristate.isTrue);
      expect(value.flagsCollection.isEnabled, Tristate.isTrue);
      expect(value.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });
  }

  testWidgets('system label is localized', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpBrightnessChrome(
      uiCubit: uiCubit,
      selectionCubit: selectionCubit,
      brightnessCubit: brightnessCubit,
      locale: const Locale('ru'),
    );
    uiCubit.showChrome();
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    expect(l10n.localeName, 'ru');
    expect(l10n.readerBrightnessSystem, isNot('System'));
    expect(
      find.bySemanticsLabel(
        l10n.readerUsingSystemBrightness(l10n.readerBrightnessSystem),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('System')), findsNothing);
    semantics.dispose();
  });

  for (final rtl in [false, true]) {
    testWidgets('brightness pill sits at the trailing edge rtl=$rtl', (
      tester,
    ) async {
      await tester.pumpBrightnessChrome(
        uiCubit: uiCubit,
        selectionCubit: selectionCubit,
        brightnessCubit: brightnessCubit,
        rtl: rtl,
      );
      uiCubit.showChrome();
      await tester.pumpAndSettle();
      expect(find.byType(PositionedDirectional), findsOneWidget);
      final pill = tester.getRect(find.byType(DecoratedBox).first);
      final width = tester.getSize(find.byType(Scaffold)).width;
      expect(rtl ? pill.left : width - pill.right, AppSpacing.lg);
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.duration, AppMotion.short);
      uiCubit.hideChrome();
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset.dx,
        rtl ? lessThan(0) : greaterThan(0),
      );
    });
  }

  testWidgets('brightness chrome fits a narrow phone at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpBrightnessChrome(
      uiCubit: uiCubit,
      selectionCubit: selectionCubit,
      brightnessCubit: brightnessCubit,
      scale: 2,
    );
    uiCubit.showChrome();
    brightnessCubit.previewBrightness(1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final pill = tester.getRect(find.byType(DecoratedBox).first);
    expect(pill.width, AppSizes.buttonHeight + AppSpacing.xs * 2);
    final label = tester.getRect(find.text('100%'));
    expect(label.left, greaterThanOrEqualTo(pill.left));
    expect(label.right, lessThanOrEqualTo(pill.right));
    for (final button in find.byType(AppPlainIconButton).evaluate()) {
      final rect = tester.getRect(find.byWidget(button.widget));
      expect(rect.left, greaterThanOrEqualTo(pill.left));
      expect(rect.right, lessThanOrEqualTo(pill.right));
      expect(rect.top, greaterThanOrEqualTo(pill.top));
      expect(rect.bottom, lessThanOrEqualTo(pill.bottom));
    }
  });

  testWidgets('brightness chrome settles in one frame under reduced motion', (
    tester,
  ) async {
    await tester.pumpBrightnessChrome(
      uiCubit: uiCubit,
      selectionCubit: selectionCubit,
      brightnessCubit: brightnessCubit,
      disableAnimations: true,
    );
    uiCubit.showChrome();
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      Duration.zero,
    );
    expect(tester.hasRunningAnimations, isFalse);
    final width = tester.getSize(find.byType(Scaffold)).width;
    expect(
      width - tester.getRect(find.byType(DecoratedBox).first).right,
      AppSpacing.lg,
    );
  });
}

extension on WidgetTester {
  Future<void> pumpBrightnessChrome({
    required ReaderUiCubit uiCubit,
    required ReaderSelectionCubit selectionCubit,
    required ReaderBrightnessCubit brightnessCubit,
    bool rtl = false,
    bool dark = false,
    bool disableAnimations = false,
    double scale = 1,
    Locale locale = const Locale('en'),
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
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
