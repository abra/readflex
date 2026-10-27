import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';
import 'package:toast_service/toast_service.dart';

import 'helpers/dictionary_sheet_harness.dart';

void main() {
  late AppDatabase db;
  late DictionaryRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DictionaryRepository(database: db);
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  const sentenceSelection = TextSelectionContext(
    selectedText: 'power',
    contextText: 'This power bank provides emergency power.',
    sourceId: 'article-1',
    sourceType: SourceType.article,
    cfiRange: 'readflex-html-position:1',
    sourceLanguageHint: 'en',
  );

  DictionaryCubit cubit({List<DictionaryLexicalEntry>? entries}) =>
      DictionaryCubit(
        dictionaryService: entries == null
            ? EntryDictionaryService()
            : EntryDictionaryService(entries: entries),
        dictionaryRepository: repository,
      );

  group('DictionaryCubit save', () {
    test(
      'saves the headword with its first definition as the meaning',
      () async {
        final c = cubit(
          entries: const [
            DictionaryLexicalEntry(
              lemma: 'power',
              partOfSpeech: 'noun',
              pronunciation: 'ˈpaʊər',
              definitions: [
                DictionaryDefinition(
                  text: 'Energy for devices.',
                  examples: ['The power went out.', 'Solar power.'],
                ),
                DictionaryDefinition(text: 'Control over others.'),
              ],
            ),
          ],
        );
        addTearDown(c.close);
        await c.lookup(sentenceSelection);

        await c.toggleSaved(sentenceSelection);

        expect(c.state.saveStatus, WordSaveStatus.saved);
        final entry = await repository.getEntryById(c.state.savedEntryId!);
        expect(entry!.word, 'power');
        expect(entry.lemma, 'power');
        expect(entry.translation, 'Energy for devices.');
        expect(entry.baseTranslation, isNull);
        expect(entry.partOfSpeech, 'noun');
        expect(entry.pronunciation, 'ˈpaʊər');
        expect(entry.context, sentenceSelection.contextText);
        expect(entry.usageExamples, ['The power went out.', 'Solar power.']);
        expect(entry.sourceId, 'article-1');
        final anchors = await repository.getAnchorsByEntry(entry.id);
        expect(anchors.single.cfiRange, 'readflex-html-position:1');
        expect(await db.reviewItemsDao.byItemId(entry.id), isNotNull);
      },
    );

    test(
      'an in-context entry becomes the meaning, the word its base',
      () async {
        final c = cubit(entries: expressionEntries);
        addTearDown(c.close);
        await c.lookup(inflectedSelection);

        await c.toggleSaved(inflectedSelection);

        final entry = await repository.getEntryById(c.state.savedEntryId!);
        expect(entry!.word, 'shutting');
        expect(entry.lemma, 'shut');
        expect(entry.translation, 'To stop a supply.');
        expect(entry.baseTranslation, 'To close.');
      },
    );

    test('toggleSaved again removes the word', () async {
      final c = cubit();
      addTearDown(c.close);
      await c.lookup(sentenceSelection);
      await c.toggleSaved(sentenceSelection);
      final id = c.state.savedEntryId!;

      await c.toggleSaved(sentenceSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
      expect(await repository.getEntryById(id), isNull);
    });

    test('a word saved earlier opens as saved', () async {
      final saved = await repository.addEntry(
        word: 'power',
        translation: 'Energy.',
        sourceId: 'article-1',
      );
      final c = cubit();
      addTearDown(c.close);

      await c.lookup(sentenceSelection);
      await Future<void>.delayed(Duration.zero);

      expect(c.state.saveStatus, WordSaveStatus.saved);
      expect(c.state.savedEntryId, saved.id);
    });

    test('nothing is saved without a result', () async {
      final c = cubit();
      addTearDown(c.close);

      await c.toggleSaved(sentenceSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
      expect(await repository.getEntryCount(), 0);
    });

    test('without a repository Save is a no-op', () async {
      final c = DictionaryCubit(dictionaryService: EntryDictionaryService());
      addTearDown(c.close);
      await c.lookup(sentenceSelection);

      await c.toggleSaved(sentenceSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
    });
  });

  group('Definition sheet Save', () {
    final saveFinder = find.byKey(const ValueKey('dictionary-save-word'));

    testWidgets('shows Save next to Copy only with a repository', (
      tester,
    ) async {
      await pumpDictionarySheet(tester);
      expect(saveFinder, findsNothing);

      await pumpDictionarySheet(tester, dictionaryRepository: repository);
      expect(saveFinder, findsOneWidget);
      final save = tester.getRect(saveFinder);
      final copy = tester.getRect(find.byType(AppCopyButton).first);
      expect(save.right, lessThanOrEqualTo(copy.left));
      expect(save.center.dy, closeTo(copy.center.dy, 1));
    });

    testWidgets('tapping Save keeps the word and turns into Saved', (
      tester,
    ) async {
      await pumpDictionarySheet(tester, dictionaryRepository: repository);

      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove from Vocabulary'), findsOneWidget);
      expect(await repository.getEntryCount(), 1);
      // The toast says where the word went; the button alone would not.
      expect(find.text('Saved for review'), findsOneWidget);
      await tester.pump(toastSuccessDuration + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Saved for review'), findsNothing);

      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save to Vocabulary'), findsOneWidget);
      expect(await repository.getEntryCount(), 0);
      // Removing is quiet: the button already shows it.
      expect(find.text('Saved for review'), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('de'), Locale('ar')]) {
      testWidgets(
        'the headword fits beside two actions at 200% text: $locale',
        (tester) async {
          await pumpDictionarySheet(
            tester,
            dictionaryRepository: repository,
            locale: locale,
            textScaler: const TextScaler.linear(2),
          );
          expect(tester.takeException(), isNull);
          expect(saveFinder, findsOneWidget);
        },
      );
    }
  });
}
