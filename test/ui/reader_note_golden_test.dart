import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_highlight_note_sheet.dart';

import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('note draft and discard ${profile.name}', (tester) async {
      await pumpGoldenSurface(
        tester,
        profile,
        (context) => Scaffold(
          body: TextButton(
            onPressed: () => showReaderHighlightNoteSheet(
              context,
              existingHighlight: true,
              initialNote: 'A comment about this part of the page.',
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'A comment to keep after reading.',
      );
      await tester.pumpAndSettle();
      final l10n = ReadflexLocalizations.of(
        tester.element(find.byType(ReaderHighlightNoteSheet)),
      )!;
      expect(find.text(l10n.commonSave).hitTestable(), findsOneWidget);
      await expectUiGolden(tester, profile, 'reader-note-draft');
      await tester.tap(find.byTooltip(l10n.commonClose));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonKeepEditing).hitTestable(), findsOneWidget);
      await expectUiGolden(tester, profile, 'reader-note-discard');
    }, tags: ['golden']);
  }
}
