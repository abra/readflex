import 'package:bloc_test/bloc_test.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  late _FakeDictionaryService successService;

  setUp(() {
    successService = _FakeDictionaryService(
      result: const DictionaryLookupResult(
        requestId: 'request-1',
        status: DictionaryLookupStatus.found,
        term: 'power',
        language: 'en',
        entries: [
          DictionaryLexicalEntry(
            lemma: 'power',
            definitions: [DictionaryDefinition(text: 'Ability to act.')],
          ),
        ],
      ),
    );
  });

  blocTest<DictionaryCubit, DictionarySheetState>(
    'builds a language-aware request and emits success',
    build: () => DictionaryCubit(dictionaryService: successService),
    act: (cubit) => cubit.lookup(_selection()),
    expect: () => [
      const DictionarySheetState(status: DictionarySheetStatus.loading),
      isA<DictionarySheetState>().having(
        (state) => state.status,
        'status',
        DictionarySheetStatus.success,
      ),
    ],
    verify: (_) {
      expect(successService.lastRequest?.term, 'power');
      expect(successService.lastRequest?.sourceLanguage, 'en');
    },
  );

  blocTest<DictionaryCubit, DictionarySheetState>(
    'maps a typed service failure to failure state',
    build: () => DictionaryCubit(
      dictionaryService: _FakeDictionaryService(
        failure: const DictionaryLookupException(
          DictionaryLookupFailureReason.network,
          'offline',
        ),
      ),
    ),
    act: (cubit) => cubit.lookup(_selection()),
    expect: () => [
      const DictionarySheetState(status: DictionarySheetStatus.loading),
      isA<DictionarySheetState>()
          .having(
            (state) => state.status,
            'status',
            DictionarySheetStatus.failure,
          )
          .having(
            (state) => state.failure?.reason,
            'reason',
            DictionaryLookupFailureReason.network,
          ),
    ],
  );
}

TextSelectionContext _selection() {
  return const TextSelectionContext(
    selectedText: 'pow',
    normalizedSelectedText: 'power',
    sourceId: 'source-1',
    sourceType: SourceType.article,
    sourceLanguageHint: 'en',
  );
}

class _FakeDictionaryService implements DictionaryLookupService {
  _FakeDictionaryService({this.result, this.failure});

  final DictionaryLookupResult? result;
  final DictionaryLookupException? failure;
  DictionaryLookupRequest? lastRequest;

  @override
  Future<DictionaryLookupResult> lookup(DictionaryLookupRequest request) async {
    lastRequest = request;
    final failure = this.failure;
    if (failure != null) throw failure;
    return result!;
  }

  @override
  void dispose() {}
}
