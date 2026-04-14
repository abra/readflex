import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_fsrs_repository.dart';

final _entry = DictionaryEntry(
  id: 'de-1',
  word: 'serendipity',
  translation: 'счастливая случайность',
  pronunciation: '/ˌsɛr.ənˈdɪp.ɪ.ti/',
  partOfSpeech: 'noun',
  addedAt: DateTime(2026),
  usageExamples: ['A serendipity led to the discovery.'],
);

final _entry2 = DictionaryEntry(
  id: 'de-2',
  word: 'ephemeral',
  translation: 'мимолётный',
  addedAt: DateTime(2026),
);

void main() {
  late FakeDictionaryRepository dictionaryRepository;
  late FakeFsrsRepository fsrsRepository;

  setUp(() {
    dictionaryRepository = FakeDictionaryRepository();
    fsrsRepository = FakeFsrsRepository();
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: DictionaryScreen(
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
      ),
    ),
  );

  testWidgets('shows error state on failure', (tester) async {
    dictionaryRepository.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Failed to load dictionary'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows empty state when no entries', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('No words found'), findsOneWidget);
  });

  testWidgets('shows Dictionary header and saved words count', (
    tester,
  ) async {
    dictionaryRepository.seed([_entry, _entry2]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Dictionary'), findsOneWidget);
    expect(find.text('2 saved words'), findsOneWidget);
  });

  testWidgets('shows mastered count badge', (tester) async {
    dictionaryRepository.seed([_entry, _entry2]);
    fsrsRepository.masteredIds = {'de-1'};

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('1 mastered'), findsOneWidget);
  });

  testWidgets('shows word card with word and translation', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('счастливая случайность'), findsOneWidget);
  });

  testWidgets('shows pronunciation and part of speech', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('/ˌsɛr.ənˈdɪp.ɪ.ti/'), findsOneWidget);
    expect(find.text('noun'), findsOneWidget);
  });

  testWidgets('shows Mastered badge for mastered entries', (tester) async {
    dictionaryRepository.seed([_entry]);
    fsrsRepository.masteredIds = {'de-1'};

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Mastered'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    dictionaryRepository.seed([_entry]);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Search words...'), findsOneWidget);
  });
}
