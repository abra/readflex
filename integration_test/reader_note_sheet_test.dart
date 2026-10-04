import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_highlight_note_sheet.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_driver.dart';

/// Native keyboard and cancellation checks for the reader's note editor.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native note draft protects cancellation and supports clearing', (
    tester,
  ) async {
    ReaderHighlightNoteResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showReaderHighlightNoteSheet(
                    context,
                    initialNote: 'Saved comment',
                    existingHighlight: true,
                  );
                },
                child: const Text('Open note'),
              ),
            ),
          ),
        ),
      ),
    );
    await tapUi(tester, find.text('Open note'));
    // Establish the native editor before sending synthetic text input; otherwise
    // its initial platform value can arrive after the test's draft update.
    await tapUi(tester, find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved comment');
    // Native keyboard insets move the sheet; tap after that transition settles.
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Unsaved comment',
      reason: 'the platform editor must retain the entered draft',
    );
    if (Platform.isAndroid) {
      await captureAndroidScreenshot('note-draft-before-close');
    } else {
      await binding.takeScreenshot('note-draft-before-close');
    }
    await tapUi(tester, find.byTooltip('Close'));
    await waitForUi(
      tester,
      () => find.text('Discard changes?').evaluate().isNotEmpty,
      description: 'note discard decision after closing a dirty draft',
    );
    if (Platform.isAndroid) {
      await captureAndroidScreenshot('note-discard');
    } else {
      await binding.takeScreenshot('note-discard');
    }
    await tapUi(tester, find.text('Keep editing'));
    expect(find.text('Unsaved comment'), findsOneWidget);
    await tapUi(tester, find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tapUi(tester, find.text('Save'));
    expect(result, isNotNull);
    expect(result!.note, isNull);
    await unmountUi(tester);
  });
}
