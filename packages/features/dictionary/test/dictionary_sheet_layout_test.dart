import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'helpers/dictionary_sheet_harness.dart';

/// The definition sheet's entry order, sections, spacing, Copy placement and
/// text fitting.
void main() {
  group('layout', () {
    Finder lemma(String text) => find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == text,
    );

    testWidgets('the expression comes first, the word meaning after it', (
      tester,
    ) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(entries: expressionEntries),
        selection: inflectedSelection,
      );
      final order = [
        lemma('shut'),
        find.text('In this context'),
        lemma('shut off'),
        find.text('To stop a supply.'),
        find.text('Word meaning'),
        find.text('To close.'),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          tester.getTopLeft(order[i - 1]).dy,
          lessThan(tester.getTopLeft(order[i]).dy),
          reason: '$i',
        );
      }
      final theme = Theme.of(tester.element(lemma('shut')));
      expect(
        tester.widget<SelectableText>(lemma('shut')).style,
        theme.textTheme.headlineSmall,
      );
      expect(
        tester.widget<SelectableText>(lemma('shut off')).style,
        theme.textTheme.titleMedium!.copyWith(
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      );
      // Captions sit 8dp above their content.
      expect(
        tester.getRect(lemma('shut off')).top -
            tester.getRect(find.text('In this context')).bottom,
        AppSpacing.sm,
      );
      expect(
        tester.getRect(find.text('To close.')).top -
            tester.getRect(find.text('Word meaning')).bottom,
        AppSpacing.sm,
      );
      expect(find.byType(Divider), findsNothing);
    });

    Rect outline(WidgetTester tester, int index) =>
        sectionOutline(tester, find.byType(AppSheetSection).at(index));
    // A definition row, number column included.
    Finder definitionRow(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(Row)).first;

    testWidgets('the expression and the word meaning are outlined sections', (
      tester,
    ) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(entries: expressionEntries),
        selection: inflectedSelection,
      );
      final sections = find.byType(AppSheetSection);
      expect(sections, findsNWidgets(2));
      for (final (index, content) in [(0, 'shut off'), (1, 'To close.')]) {
        expect(
          find.descendant(of: sections.at(index), matching: find.text(content)),
          findsOneWidget,
        );
      }
      // The headword stays above the sections.
      expect(
        find.descendant(of: sections.first, matching: lemma('shut')),
        findsNothing,
      );
    });

    testWidgets('a single entry has one untitled section', (tester) async {
      await pumpDictionarySheet(tester);
      expect(find.byType(AppSheetSection), findsOneWidget);
      expect(
        tester.widget<AppSheetSection>(find.byType(AppSheetSection)).title,
        isNull,
      );
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('sections keep their spacing at ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(390, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpDictionarySheet(
          tester,
          textScaler: TextScaler.linear(scale),
          service: EntryDictionaryService(entries: expressionEntries),
          selection: inflectedSelection,
        );
        final metadata = find.byType(AppLexicalMetadataRow);
        final first = outline(tester, 0);
        final second = outline(tester, 1);
        expect(
          first.top - tester.getRect(metadata.first).bottom,
          AppSpacing.lg,
        );
        expect(second.top - first.bottom, AppSpacing.md);
        expect(
          tester.getRect(find.text('In this context')).top - first.top,
          AppSpacing.md,
        );
        expect(
          tester.getRect(definitionRow('To stop a supply.')).top -
              tester.getRect(metadata.at(1)).bottom,
          AppSpacing.md,
        );
        expect(
          first.bottom -
              tester.getRect(definitionRow('To stop a supply.')).bottom,
          AppSpacing.md,
        );
        expect(
          tester.getRect(find.text('Word meaning')).top - second.top,
          AppSpacing.md,
        );
        expect(
          second.bottom - tester.getRect(definitionRow('To close.')).bottom,
          AppSpacing.md,
        );
      });
    }

    testWidgets('an entry without definitions keeps 12dp below its lemma', (
      tester,
    ) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(
          entries: const [
            DictionaryLexicalEntry(
              lemma: 'shut',
              definitions: [DictionaryDefinition(text: 'To close.')],
            ),
            DictionaryLexicalEntry(
              lemma: 'shut off',
              partOfSpeech: 'verb',
              definitions: [],
            ),
          ],
        ),
        selection: inflectedSelection,
      );
      final metadata = find.byType(AppLexicalMetadataRow).last;
      expect(
        outline(tester, 0).bottom - tester.getRect(metadata).bottom,
        AppSpacing.md,
      );
    });

    testWidgets('Copy reaches the outline of its section', (tester) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(entries: expressionEntries),
        selection: inflectedSelection,
      );
      final copy = tester.getRect(find.byType(AppCopyButton).at(1));
      expect(copy.right, moreOrLessEquals(outline(tester, 0).right));
    });

    testWidgets('a single entry has no captions', (tester) async {
      await pumpDictionarySheet(tester);
      expect(find.text('In this context'), findsNothing);
      expect(find.text('Word meaning'), findsNothing);
    });

    testWidgets('further entries follow the word meaning as small headings', (
      tester,
    ) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(
          entries: const [
            ...expressionEntries,
            DictionaryLexicalEntry(
              lemma: 'shutter',
              partOfSpeech: 'noun',
              definitions: [DictionaryDefinition(text: 'A window cover.')],
            ),
          ],
        ),
        selection: inflectedSelection,
      );
      await tester.ensureVisible(lemma('shutter'));
      expect(
        tester.getTopLeft(find.text('To close.')).dy,
        lessThan(tester.getTopLeft(lemma('shutter')).dy),
      );
      final theme = Theme.of(tester.element(lemma('shutter')));
      expect(
        tester.widget<SelectableText>(lemma('shutter')).style,
        theme.textTheme.titleMedium!.copyWith(
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      );
      expect(find.byType(AppCopyButton), findsNWidgets(3));
    });

    testWidgets('each Copy is centered on its lemma line', (tester) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(entries: expressionEntries),
        selection: inflectedSelection,
      );
      final copies = find.byType(AppCopyButton);
      for (final (index, text) in ['shut', 'shut off'].indexed) {
        final style = tester.widget<SelectableText>(lemma(text)).style!;
        final line = style.fontSize! * style.height!;
        expect(
          tester.getCenter(copies.at(index)).dy,
          moreOrLessEquals(tester.getRect(lemma(text)).top + line / 2),
          reason: text,
        );
      }
    });

    testWidgets('in an Arabic UI the English entry keeps its edge, captions '
        'theirs', (tester) async {
      await pumpDictionarySheet(
        tester,
        locale: const Locale('ar'),
        service: EntryDictionaryService(
          entries: const [
            DictionaryLexicalEntry(
              lemma: 'shut',
              pronunciation: '/ʃʌt/',
              partOfSpeech: 'verb',
              definitions: [DictionaryDefinition(text: 'To close.')],
            ),
            DictionaryLexicalEntry(
              lemma: 'shut off',
              partOfSpeech: 'phrasal verb',
              definitions: [DictionaryDefinition(text: 'To stop a supply.')],
            ),
          ],
        ),
        selection: inflectedSelection,
      );
      final context = tester.element(find.byType(DictionarySheet));
      final sheet = tester.getRect(find.byType(DictionarySheet));
      for (final caption in [
        context.l10n.dictionaryInContext,
        context.l10n.dictionaryWordMeaning,
      ]) {
        await tester.ensureVisible(find.text(caption));
        expect(
          sheet.right - tester.getRect(find.text(caption)).right,
          AppSpacing.xl,
          reason: caption,
        );
      }
      await tester.ensureVisible(lemma('shut'));
      final headword = tester.getRect(lemma('shut'));
      // The heading line starts with the selected form, `shutting -> shut`.
      final form = tester.getRect(find.text('shutting'));
      expect(form.left - sheet.left, AppSpacing.xl);
      expect(headword.left, greaterThan(form.right));
      // The metadata row starts under the heading, not on the UI's edge.
      expect(tester.getRect(find.text('/ʃʌt/')).left, form.left);
      final copy = tester.getRect(find.byType(AppCopyButton).first);
      expect(copy.left, greaterThan(headword.right));
    });

    testWidgets('a long lemma shrinks at large text instead of breaking', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Test glyphs are squares: at 2x the word does not fit at the heading
      // size and fits at a smaller one.
      const word = 'fortune';
      await pumpDictionarySheet(
        tester,
        textScaler: const TextScaler.linear(2),
        selection: const TextSelectionContext(
          selectedText: word,
          sourceId: 'article-1',
          sourceType: SourceType.article,
        ),
        service: EntryDictionaryService(
          entries: const [
            DictionaryLexicalEntry(
              lemma: word,
              definitions: [DictionaryDefinition(text: 'Wealth.')],
            ),
          ],
        ),
      );
      final theme = Theme.of(tester.element(lemma(word)));
      final style = tester.widget<SelectableText>(lemma(word)).style!;
      expect(
        style.fontSize,
        lessThan(theme.textTheme.headlineSmall!.fontSize!),
      );
      expect(
        style.fontSize,
        greaterThanOrEqualTo(theme.textTheme.bodyMedium!.fontSize!),
      );
      expect(
        tester.getSize(lemma(word)).height,
        closeTo(2 * style.fontSize! * style.height!, 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a found term without entries reads as not found', (
      tester,
    ) async {
      await pumpDictionarySheet(
        tester,
        service: EntryDictionaryService(entries: const []),
      );
      final context = tester.element(find.byType(DictionarySheet));
      expect(find.text(context.l10n.dictionaryNotFoundTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
