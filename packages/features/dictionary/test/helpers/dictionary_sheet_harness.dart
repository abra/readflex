import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

// Shared by the definition sheet tests: pumping the sheet, a fake service,
// entries and selections.

Future<void> pumpDictionarySheet(
  WidgetTester tester, {
  DictionaryLookupService? service,
  TextSelectionContext selection = powerSelection,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  DictionaryRepository? dictionaryRepository,
}) async {
  late BuildContext sheetContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: readflexLocalizationsDelegates,
      supportedLocales: ReadflexSupportedLocales.locales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          sheetContext = context;
          return const Scaffold();
        },
      ),
    ),
  );
  showDictionarySheet(
    sheetContext,
    selection: selection,
    dictionaryService: service ?? EntryDictionaryService(),
    dictionaryRepository: dictionaryRepository,
  );
  await tester.pumpAndSettle();
}

const inflectedSelection = TextSelectionContext(
  selectedText: 'shutting',
  contextText: 'The device saves power by shutting off its display.',
  markedContextText: 'The device saves power by [[shutting]] off its display.',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const expressionEntries = [
  DictionaryLexicalEntry(
    lemma: 'shut',
    partOfSpeech: 'verb',
    definitions: [DictionaryDefinition(text: 'To close.')],
  ),
  DictionaryLexicalEntry(
    lemma: 'shut off',
    partOfSpeech: 'phrasal verb',
    definitions: [DictionaryDefinition(text: 'To stop a supply.')],
  ),
];

class EntryDictionaryService implements DictionaryLookupService {
  EntryDictionaryService({
    this.entries = const [
      DictionaryLexicalEntry(
        lemma: 'power',
        partOfSpeech: 'noun',
        definitions: [DictionaryDefinition(text: 'Energy for devices.')],
      ),
    ],
  });

  final List<DictionaryLexicalEntry> entries;
  var calls = 0;

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) async {
    calls++;
    return DictionaryLookupResult(
      requestId: request.requestId,
      status: DictionaryLookupStatus.found,
      term: request.term,
      language: 'en',
      entries: entries,
    );
  }

  @override
  void dispose() {}
}

const powerSelection = TextSelectionContext(
  selectedText: 'power',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

/// The outline of [section]: its full height, [AppSheetSection.outlineInsetFor]
/// in from either side.
Rect sectionOutline(WidgetTester tester, Finder section) {
  final rect = tester.getRect(section);
  final inset = AppSheetSection.outlineInsetFor(tester.element(section));
  return Rect.fromLTRB(
    rect.left + inset,
    rect.top,
    rect.right - inset,
    rect.bottom,
  );
}
