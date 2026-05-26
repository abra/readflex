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

  testWidgets('renders compact Aa sheet without an embedded preview', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    expect(find.text('Aa'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('TYPEFACE'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);
    expect(find.text('PREVIEW'), findsNothing);
  });

  testWidgets('switches between appearance sections', (tester) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();

    expect(find.text('SPACING'), findsOneWidget);
    expect(find.text('MARGINS'), findsOneWidget);
    expect(find.text('ALIGNMENT'), findsOneWidget);
    expect(find.text('TYPEFACE'), findsNothing);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('READING THEME'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
  });

  testWidgets('selects rounded default line spacing preset', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();

    expect(find.text('1.6'), findsNWidgets(2));
    final activeSpacing = tester.widget<Container>(
      find.byKey(const ValueKey('reader-line-height-1.6')),
    );
    final activeDecoration = activeSpacing.decoration! as BoxDecoration;
    expect(activeDecoration.color, isNot(Colors.transparent));

    final inactiveSpacing = tester.widget<Container>(
      find.byKey(const ValueKey('reader-line-height-1.4')),
    );
    final inactiveDecoration = inactiveSpacing.decoration! as BoxDecoration;
    expect(inactiveDecoration.color, Colors.transparent);
  });

  testWidgets('persists text alignment from layout panel', (tester) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.text('Justify'), findsOneWidget);

    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    expect(
      cubit.state.effectiveAppearance.textAlignment,
      ReaderTextAlignment.end,
    );
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textAlignment,
      ReaderTextAlignment.end,
    );

    await tester.tap(find.text('Justify'));
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

  testWidgets('persists font changes and resets source override from header', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('PT Serif'));
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

  testWidgets('tapping size percent clears text size override', (
    tester,
  ) async {
    await tester.openAppearanceSheet(cubit);

    await tester.tap(find.text('A+'));
    await tester.pump();

    expect(find.text('105%'), findsOneWidget);

    await tester.tap(find.text('105%'));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));

    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
  });

  testWidgets('size percent resets inherited global scale to 100%', (
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
    expect(find.text('115%'), findsOneWidget);
    expect(preferencesService.readerAppearanceOverrideFor(_sourceId), isNull);
    expect(cubit.state.effectiveAppearance.textScale, 1.15);

    await tester.tap(find.text('115%'));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    expect(
      preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
      1.0,
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

extension on WidgetTester {
  Future<void> openAppearanceSheet(
    ReaderAppearanceCubit cubit,
  ) async {
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
                    onPressed: () => showReaderAppearanceSheet(context),
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
