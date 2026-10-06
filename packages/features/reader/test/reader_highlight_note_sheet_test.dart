import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_highlight_note_sheet.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    String? initialNote,
    bool existingHighlight = false,
    required ValueChanged<ReaderHighlightNoteResult?> onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showReaderHighlightNoteSheet(
                  context,
                  initialNote: initialNote,
                  existingHighlight: existingHighlight,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final initial in [null, 'Old note']) {
    testWidgets(
      'saved highlight can ${initial == null ? 'add' : 'clear'} note',
      (tester) async {
        ReaderHighlightNoteResult? result;
        await open(
          tester,
          initialNote: initial,
          existingHighlight: true,
          onResult: (value) => result = value,
        );
        await tester.enterText(
          find.byType(TextField),
          initial == null ? ' New note ' : '  ',
        );
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.note, initial == null ? 'New note' : null);
      },
    );
  }

  testWidgets('saved highlight shows one full-width Save command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(
      tester,
      initialNote: 'Old note',
      existingHighlight: true,
      onResult: (_) {},
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(AppSheetActions), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    final save = tester.getRect(find.byType(FilledButton));
    expect(save.left, AppSpacing.xl);
    expect(save.right, 390 - AppSpacing.xl);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );

    await tester.enterText(find.byType(TextField), 'Old note ');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );

    await tester.enterText(find.byType(TextField), 'Changed');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isTrue,
    );
  });

  for (final action in ['Close', 'Back']) {
    testWidgets('saved highlight: $action protects the draft without writing', (
      tester,
    ) async {
      var completed = false;
      ReaderHighlightNoteResult? result;
      await open(
        tester,
        initialNote: 'Old note',
        existingHighlight: true,
        onResult: (value) {
          completed = true;
          result = value;
        },
      );
      await tester.enterText(find.byType(TextField), 'Draft');
      if (action == 'Back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Close'));
      }
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
    });
  }

  testWidgets('discard is the outlined error command in the sheet footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await open(
      tester,
      initialNote: 'Old note',
      existingHighlight: true,
      onResult: (_) {},
    );
    final field = tester.getRect(find.byType(TextField));
    final actions = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    // Body 16 + footer 8 between the last line and the command; footer 16
    // plus the route's 16 minimum below it.
    expect(actions.top - field.bottom, AppSpacing.xl);
    expect(844 - actions.bottom, AppSpacing.lg * 2);
    expect(actions.left, AppSpacing.xl);
    expect(actions.right, 390 - AppSpacing.xl);
    expect(field.left, AppSpacing.xl);
    expect(field.right, 390 - AppSpacing.xl);

    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    final colors = tester.element(find.byType(AppSheetActions)).colors;
    final discard = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Discard'),
    );
    expect(discard.style?.foregroundColor?.resolve({}), colors.error);
    expect(discard.style?.side?.resolve({})?.color, colors.error);
    expect(find.widgetWithText(FilledButton, 'Keep editing'), findsOneWidget);
    // The confirmation keeps the form and the footer rhythm; longer labels
    // may stack the commands but never change the gaps.
    final confirm = tester.getRect(find.byType(AppSheetActions));
    expect(confirm.top - tester.getRect(find.byType(TextField)).bottom, 24);
    expect(844 - confirm.bottom, AppSpacing.lg * 2);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('new highlight keeps the Skip and Save pair', (tester) async {
    await open(tester, onResult: (_) {});
    expect(find.byType(AppSheetActions), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
      isTrue,
    );
  });

  testWidgets('skip is an explicit empty result, not cancellation', (
    tester,
  ) async {
    var completed = false;
    ReaderHighlightNoteResult? result;
    await open(
      tester,
      onResult: (value) {
        completed = true;
        result = value;
      },
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNotNull);
    expect(result!.note, isNull);
  });

  testWidgets('new highlight: Close pops null without a note result', (
    tester,
  ) async {
    var completed = false;
    ReaderHighlightNoteResult? result = const ReaderHighlightNoteResult('x');
    await open(
      tester,
      onResult: (value) {
        completed = true;
        result = value;
      },
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });
}
