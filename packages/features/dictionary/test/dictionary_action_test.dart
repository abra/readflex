import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

void main() {
  testWidgets('stops after the system dictionary presents a definition', (
    tester,
  ) async {
    final systemService = _FakeSystemDictionaryService(presented: true);
    final remoteService = _FakeLookupService();
    final action = DictionaryAction(
      systemDictionaryService: systemService,
      dictionaryLookupService: remoteService,
    );
    await tester.pumpWidget(_ActionHost(action: action));

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    expect(systemService.term, 'power');
    expect(remoteService.lookupCount, 0);
    expect(find.text('Definition'), findsNothing);
  });

  testWidgets('falls back to Readflex when system lookup is unavailable', (
    tester,
  ) async {
    final systemService = _FakeSystemDictionaryService(presented: false);
    final remoteService = _FakeLookupService();
    final action = DictionaryAction(
      systemDictionaryService: systemService,
      dictionaryLookupService: remoteService,
    );
    await tester.pumpWidget(_ActionHost(action: action));

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    expect(remoteService.lookupCount, 1);
    expect(remoteService.lastRequest?.term, 'power');
    expect(
      remoteService.lastRequest?.contextText,
      'The [[power]] bank is compact.',
    );
    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('No definition found'), findsOneWidget);
  });

  testWidgets('renders monolingual entries returned by Readflex', (
    tester,
  ) async {
    final remoteService = _FakeLookupService(
      result: const DictionaryLookupResult(
        requestId: 'request-1',
        status: DictionaryLookupStatus.found,
        term: 'power',
        language: 'en',
        entries: [
          DictionaryLexicalEntry(
            lemma: 'power',
            pronunciation: '/paur/',
            partOfSpeech: 'noun',
            definitions: [
              DictionaryDefinition(
                text: 'The capacity to act or produce an effect.',
                examples: ['The battery supplies power to the device.'],
              ),
            ],
          ),
        ],
      ),
    );
    final action = DictionaryAction(
      systemDictionaryService: _FakeSystemDictionaryService(presented: false),
      dictionaryLookupService: remoteService,
    );
    await tester.pumpWidget(_ActionHost(action: action));

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    expect(find.text('power'), findsNWidgets(2));
    expect(find.text('/paur/ · noun'), findsOneWidget);
    expect(
      find.text('The capacity to act or produce an effect.'),
      findsOneWidget,
    );
    expect(
      find.text('The battery supplies power to the device.'),
      findsOneWidget,
    );
  });
}

class _ActionHost extends StatelessWidget {
  const _ActionHost({required this.action});

  final DictionaryAction action;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => action.onExecute(context, _selection),
            child: const Text('Run'),
          ),
        ),
      ),
    );
  }
}

const _selection = TextSelectionContext(
  selectedText: 'pow',
  normalizedSelectedText: 'power',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
  contextText: 'The power bank is compact.',
  normalizedMarkedContextText: 'The [[power]] bank is compact.',
);

class _FakeSystemDictionaryService implements SystemDictionaryService {
  _FakeSystemDictionaryService({required this.presented});

  final bool presented;
  String? term;

  @override
  Future<bool> showDefinition(String term) async {
    this.term = term;
    return presented;
  }
}

class _FakeLookupService implements DictionaryLookupService {
  _FakeLookupService({this.result});

  final DictionaryLookupResult? result;
  int lookupCount = 0;
  DictionaryLookupRequest? lastRequest;

  @override
  Future<DictionaryLookupResult> lookup(DictionaryLookupRequest request) async {
    lookupCount++;
    lastRequest = request;
    return result ??
        DictionaryLookupResult(
          requestId: request.requestId,
          status: DictionaryLookupStatus.notFound,
          term: request.term,
          language: request.sourceLanguage,
        );
  }

  @override
  void dispose() {}
}
