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

  for (final action in ['Close', 'Cancel', 'Back']) {
    testWidgets('$action protects the note draft without writing', (
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
        await tester.tap(
          action == 'Close' ? find.byTooltip('Close') : find.text(action),
        );
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

  testWidgets('skip is an explicit empty result, not cancellation', (
    tester,
  ) async {
    ReaderHighlightNoteResult? result;
    await open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.note, isNull);
  });
}
