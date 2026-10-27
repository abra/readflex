import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:toast_service/toast_service.dart';
import 'package:translate/translate.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';

import 'helpers/translate_sheet_harness.dart';

void main() {
  late AppDatabase db;
  late DictionaryRepository repository;
  late PreferencesService preferences;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DictionaryRepository(database: db);
    preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    await preferences.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
    );
  });

  tearDown(() async {
    await preferences.dispose();
    await repository.dispose();
    await db.close();
  });

  TranslateCubit cubit({DictionaryRepository? dictionaryRepository}) =>
      TranslateCubit(
        translationService: WordTranslationService(
          const ContextualTranslationText(
            contextualTranslation: 'мощность',
            baseTranslation: 'сила',
            sentenceTranslation: 'Этот аккумулятор даёт аварийное питание.',
          ),
          analysis: const ContextualTranslationAnalysis(
            lemma: 'power',
            partOfSpeech: 'noun',
            pronunciation: 'ˈpaʊər',
          ),
        ),
        preferencesService: preferences,
        dictionaryRepository: dictionaryRepository ?? repository,
      );

  group('TranslateCubit save', () {
    test('a fresh word is not saved', () async {
      final c = cubit();
      addTearDown(c.close);
      await c.translate(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
      expect(c.state.savedEntryId, isNull);
    });

    test('toggleSaved stores the word with its answers and anchor', () async {
      final c = cubit();
      addTearDown(c.close);
      await c.translate(powerSelection);

      await c.toggleSaved(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.saved);
      final entry = await repository.getEntryById(c.state.savedEntryId!);
      expect(entry, isNotNull);
      expect(entry!.word, 'power');
      expect(entry.translation, 'мощность');
      expect(entry.baseTranslation, 'сила');
      expect(
        entry.contextTranslation,
        'Этот аккумулятор даёт аварийное питание.',
      );
      expect(entry.lemma, 'power');
      expect(entry.partOfSpeech, 'noun');
      expect(entry.pronunciation, 'ˈpaʊər');
      expect(entry.context, powerSelection.contextText);
      expect(entry.sourceId, 'source-1');
      expect(entry.sourceType, SourceType.article);
      expect(await db.reviewItemsDao.byItemId(entry.id), isNotNull);
    });

    test('toggleSaved again removes the word', () async {
      final c = cubit();
      addTearDown(c.close);
      await c.translate(powerSelection);
      await c.toggleSaved(powerSelection);
      final id = c.state.savedEntryId!;

      await c.toggleSaved(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
      expect(c.state.savedEntryId, isNull);
      expect(await repository.getEntryById(id), isNull);
      expect(await db.reviewItemsDao.byItemId(id), isNull);
    });

    test('a word saved earlier from the same source opens as saved', () async {
      final saved = await repository.addEntry(
        word: 'Power',
        translation: 'сила',
        sourceId: 'source-1',
      );
      final c = cubit();
      addTearDown(c.close);

      await c.translate(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.saved);
      expect(c.state.savedEntryId, saved.id);
    });

    test('a word saved from another source is not reported saved', () async {
      await repository.addEntry(
        word: 'power',
        translation: 'сила',
        sourceId: 'other',
      );
      final c = cubit();
      addTearDown(c.close);

      await c.translate(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
    });

    test('without a repository nothing is saved', () async {
      final c = TranslateCubit(
        translationService: const FakeTranslationService(),
        preferencesService: preferences,
      );
      addTearDown(c.close);
      await c.translate(powerSelection);

      await c.toggleSaved(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
      expect(await repository.getEntryCount(), 0);
    });

    test('nothing is saved before a translation arrived', () async {
      final c = cubit();
      addTearDown(c.close);

      await c.toggleSaved(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.notSaved);
      expect(await repository.getEntryCount(), 0);
    });

    test('a storage failure is reported and leaves nothing behind', () async {
      await db.customStatement('''
        CREATE TRIGGER fail_word_insert BEFORE INSERT ON dictionary_table
        BEGIN SELECT RAISE(ABORT, 'Test storage failure'); END;
      ''');
      final c = cubit();
      addTearDown(c.close);
      await c.translate(powerSelection);

      await c.toggleSaved(powerSelection);

      expect(c.state.saveStatus, WordSaveStatus.failure);
      expect(c.state.savedEntryId, isNull);
      expect(await repository.getEntryCount(), 0);
    });
  });

  group('Translation sheet Save', () {
    final saveFinder = find.byKey(const ValueKey('translation-save-word'));

    testWidgets('shows Save beside the word only with a repository', (
      tester,
    ) async {
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: const FakeTranslationService(includeLexicalDetails: true),
      );
      expect(saveFinder, findsNothing);

      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: const FakeTranslationService(includeLexicalDetails: true),
        dictionaryRepository: repository,
      );
      expect(saveFinder, findsOneWidget);
      expect(find.byTooltip('Save to Vocabulary'), findsOneWidget);
      final word = tester.getRect(selectedFragmentFinder);
      final save = tester.getRect(saveFinder);
      expect(save.left, greaterThan(word.right));
      expect(save.center.dy, closeTo(word.center.dy, word.height));
    });

    testWidgets('has no Save for text translation', (tester) async {
      await pumpTranslateSheet(
        tester,
        selection: paragraphSelection,
        dictionaryRepository: repository,
      );

      expect(saveFinder, findsNothing);
    });

    testWidgets('tapping Save keeps the word and turns into Saved', (
      tester,
    ) async {
      await pumpTranslateSheet(
        tester,
        selection: powerSelection,
        service: const FakeTranslationService(includeLexicalDetails: true),
        dictionaryRepository: repository,
      );

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

    testWidgets('localized tooltips fit every locale at 200% text', (
      tester,
    ) async {
      for (final locale in const [Locale('ru'), Locale('de'), Locale('ar')]) {
        await pumpTranslateSheet(
          tester,
          selection: powerSelection,
          service: const FakeTranslationService(includeLexicalDetails: true),
          dictionaryRepository: repository,
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
        expect(saveFinder, findsOneWidget, reason: '$locale');
      }
    });
  });
}
