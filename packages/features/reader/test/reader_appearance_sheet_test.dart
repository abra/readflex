import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _sourceId = 'source-1';

void main() {
  late PreferencesService preferencesService;
  late ReaderAppearanceCubit cubit;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    cubit = ReaderAppearanceCubit(
      preferencesService: preferencesService,
      sourceId: _sourceId,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  testWidgets('renders compact appearance sheet without tabs or preview', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Layout'), findsNothing);
    expect(find.text('Snow'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Graphite'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
    final fontLabel = tester.widget<Text>(find.text('Literata'));
    final decreaseLabel = tester.widget<Text>(find.text('A-'));
    final increaseLabel = tester.widget<Text>(find.text('A+'));

    expect(fontLabel.style?.fontSize, greaterThanOrEqualTo(20));
    expect(decreaseLabel.style?.fontSize, 20);
    expect(increaseLabel.style?.fontSize, 24);
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.text('Page turn'), findsOneWidget);
    expect(find.text('Page margins'), findsOneWidget);
    expect(find.text('Text alignment'), findsOneWidget);
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(VerticalDivider), findsNWidgets(3));
  });

  testWidgets('hides page turn controls for vertical article reader', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit, showPageTurnControls: false);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.text('Page turn'), findsNothing);
    expect(find.byIcon(AppIcons.pageTurnHorizontal), findsNothing);
    expect(find.byIcon(AppIcons.pageTurnVertical), findsNothing);
    expect(find.text('Page margins'), findsOneWidget);
    expect(find.text('Text alignment'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('theme swatches persist reader theme', (tester) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.themeId, 'night');
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.themeId,
      'night',
    );
  });

  testWidgets('font tile cycles through font presets', (tester) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Literata'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.fontId, 'ptSerif');
    expect(find.text('PT Serif'), findsOneWidget);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.fontId,
      'ptSerif',
    );
  });

  testWidgets('font label shows Open Sans without ellipsis', (tester) async {
    await tester.openAppearanceSheet(cubit);

    final initialDotsTop = tester
        .getTopLeft(find.byKey(const ValueKey('reader-font-page-dots')))
        .dy;

    await tester.tap(find.text('Literata'));
    await tester.pumpAndSettle();
    final ptSerifDotsTop = tester
        .getTopLeft(find.byKey(const ValueKey('reader-font-page-dots')))
        .dy;

    await tester.tap(find.text('PT Serif'));
    await tester.pumpAndSettle();
    final openSansDotsTop = tester
        .getTopLeft(find.byKey(const ValueKey('reader-font-page-dots')))
        .dy;

    final fontLabel = tester.widget<Text>(
      find.byKey(const ValueKey('reader-font-label')),
    );

    expect(fontLabel.data, 'Open Sans');
    expect(fontLabel.overflow, isNull);
    expect(ptSerifDotsTop, closeTo(initialDotsTop, 0.1));
    expect(openSansDotsTop, closeTo(initialDotsTop, 0.1));
  });

  testWidgets('appearance sheet does not reserve fixed tab body height', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(_fixedTabBodyHeightFinder(), findsNothing);
  });

  testWidgets('selects rounded default line spacing preset', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('1.6'), findsOneWidget);
    Text lineHeightText(String value) {
      return tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('reader-line-height-$value')),
          matching: find.text(value),
        ),
      );
    }

    final primary = Theme.of(
      tester.element(find.byKey(const ValueKey('reader-line-height-1.6'))),
    ).colorScheme.primary;
    expect(lineHeightText('1.6').style?.color, primary);
    expect(lineHeightText('1.4').style?.color, isNot(primary));
  });

  testWidgets('persists text alignment from layout panel', (tester) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('Start'), findsNothing);
    expect(find.text('End'), findsNothing);
    expect(find.text('Justify'), findsNothing);

    await tester.tap(find.byIcon(AppIcons.alignEnd));
    await tester.pumpAndSettle();

    expect(
      cubit.state.effectiveAppearance.textAlignment,
      ReaderTextAlignment.end,
    );
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textAlignment,
      ReaderTextAlignment.end,
    );

    await tester.tap(find.byIcon(AppIcons.alignJustify));
    await tester.pumpAndSettle();

    expect(
      cubit.state.effectiveAppearance.textAlignment,
      ReaderTextAlignment.justify,
    );
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textAlignment,
      ReaderTextAlignment.justify,
    );
  });

  testWidgets('persists page turn style from layout panel', (tester) async {
    await tester.openAppearanceSheet(cubit);

    final primary = Theme.of(
      tester.element(find.byIcon(AppIcons.pageTurnHorizontal)),
    ).colorScheme.primary;

    expect(find.byIcon(AppIcons.pageTurnHorizontal), findsOneWidget);
    expect(find.byIcon(AppIcons.pageTurnVertical), findsOneWidget);
    expect(find.text('Horizontal'), findsNothing);
    expect(find.text('Vertical'), findsNothing);
    expect(find.text('Instant'), findsNothing);

    final horizontalIcon = tester.widget<Icon>(
      find.byIcon(AppIcons.pageTurnHorizontal),
    );
    expect(horizontalIcon.color, primary);

    await tester.tap(find.byIcon(AppIcons.pageTurnVertical));
    await tester.pumpAndSettle();

    final verticalIcon = tester.widget<Icon>(
      find.byIcon(AppIcons.pageTurnVertical),
    );
    expect(verticalIcon.color, primary);
    expect(
      cubit.state.effectiveAppearance.pageTurnStyle,
      ReaderPageTurnStyle.vertical,
    );
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.pageTurnStyle,
      ReaderPageTurnStyle.vertical,
    );
  });

  testWidgets('margin stepper previews and persists side margin', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.byType(Slider), findsNothing);
    expect(find.text('8%'), findsWidgets);

    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pump();

    expect(cubit.state.effectiveAppearance.sideMargin, 9);
    expect(find.text('9%'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 300));

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.sideMargin,
      9,
    );

    await tester.tap(find.text('9%'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.sideMargin, 8);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.sideMargin,
      isNull,
    );
  });

  testWidgets('persists font changes and resets source override from header', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Literata'));
    await tester.pumpAndSettle();

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.fontId,
      'ptSerif',
    );

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(cubit.state.hasOverride, isFalse);
  });

  testWidgets('text size buttons preview and persist source override', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.text('A+'));
    await tester.pump();

    expect(cubit.state.effectiveAppearance.textScale, closeTo(1.05, 0.001));
    expect(find.text('105%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      closeTo(1.05, 0.001),
    );

    await tester.tap(find.text('105%'));
    await tester.pumpAndSettle();

    expect(cubit.state.effectiveAppearance.textScale, 1);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      isNull,
    );
  });

  testWidgets('text size buttons override inherited global scale', (
    tester,
  ) async {
    await preferencesService.update(
      (prefs) => prefs.copyWith(readerTextScale: 1.15),
    );
    await tester.pump();

    await tester.openAppearanceSheet(cubit);

    final resetButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reset'),
    );
    expect(resetButton.onPressed, isNull);
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(cubit.state.effectiveAppearance.textScale, 1.15);

    await tester.tap(find.text('A-'));
    await tester.pump();

    expect(cubit.state.effectiveAppearance.textScale, closeTo(1.10, 0.001));

    await tester.pump(const Duration(milliseconds: 300));

    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      closeTo(1.10, 0.001),
    );
  });

  testWidgets('restores reader chrome after appearance sheet is fully hidden', (
    tester,
  ) async {
    final uiCubit = ReaderUiCubit()..showChrome();
    addTearDown(uiCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: uiCubit),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      final readerUiCubit = context.read<ReaderUiCubit>();
                      readerUiCubit.beginAppearanceSheet();
                      showReaderAppearanceSheet(
                        context,
                        onFullyHidden: readerUiCubit.appearanceSheetHidden,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(uiCubit.state.chromeVisible, isFalse);
    expect(uiCubit.state.appearanceSheetVisible, isTrue);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(uiCubit.state.chromeVisible, isFalse);
    expect(uiCubit.state.appearanceSheetVisible, isTrue);

    await tester.pumpAndSettle();

    expect(uiCubit.state.chromeVisible, isTrue);
    expect(uiCubit.state.overlay, ReaderOverlay.none);
  });
}

Finder _fixedTabBodyHeightFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is SizedBox && widget.height == 360,
    description: 'fixed 360px appearance tab body',
  );
}

extension on WidgetTester {
  Future<void> openAppearanceSheet(
    ReaderAppearanceCubit cubit, {
    bool showPageTurnControls = true,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showReaderAppearanceSheet(
                      context,
                      showPageTurnControls: showPageTurnControls,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tap(find.text('Open'));
    await pumpAndSettle();
  }
}
