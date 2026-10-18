import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('request serializes the stable wire contract', () {
    final request = DictionaryLookupRequest(
      requestId: 'request-1',
      term: ' power ',
      sourceLanguage: ' en ',
      contextText: ' The [[power]] bank is compact. ',
    );

    expect(request.toJson(), {
      'request_id': 'request-1',
      'term': ' power ',
      'source_language': 'en',
      'context_text': 'The [[power]] bank is compact.',
    });
  });

  test('cache key is the wire payload without the request ID', () {
    final request = DictionaryLookupRequest(
      requestId: 'request-1',
      term: 'power',
      sourceLanguage: ' en ',
      contextText: ' The [[power]] bank. ',
    );

    expect(request.toCacheKey(), isNot(contains('request-1')));
    expect(
      request.toCacheKey(),
      DictionaryLookupRequest(
        requestId: 'request-2',
        term: 'power',
        sourceLanguage: 'en',
        contextText: 'The [[power]] bank.',
      ).toCacheKey(),
      reason: 'the same normalized wire payload asks the same question',
    );
    const context = 'The [[power]] bank.';
    for (final other in [
      DictionaryLookupRequest(
        term: 'powers',
        sourceLanguage: 'en',
        contextText: context,
      ),
      DictionaryLookupRequest(
        term: 'power',
        sourceLanguage: 'de',
        contextText: context,
      ),
      DictionaryLookupRequest(term: 'power', contextText: context),
      DictionaryLookupRequest(
        term: 'power',
        sourceLanguage: 'en',
        contextText: 'Another [[power]].',
      ),
      DictionaryLookupRequest(term: 'power', sourceLanguage: 'en'),
    ]) {
      expect(request.toCacheKey(), isNot(other.toCacheKey()));
    }
  });

  test('result parses lexical entries and definitions', () {
    final result = DictionaryLookupResult.fromJson({
      'request_id': 'request-1',
      'status': 'found',
      'term': 'power',
      'language': 'en',
      'entries': [
        {
          'lemma': 'power',
          'language': 'en',
          'pronunciation': '/paʊər/',
          'part_of_speech': 'noun',
          'definitions': [
            {
              'text': 'The ability to act or produce an effect.',
              'examples': ['Knowledge is power.'],
            },
          ],
        },
      ],
    });

    expect(result.requestId, 'request-1');
    expect(result.status, DictionaryLookupStatus.found);
    expect(result.entries.single.partOfSpeech, 'noun');
    expect(result.entries.single.definitions.single.examples, [
      'Knowledge is power.',
    ]);
  });

  test('result preserves primary and contextual entry order', () {
    final result = DictionaryLookupResult.fromJson({
      'request_id': 'request-2',
      'status': 'found',
      'term': 'shutting',
      'language': 'en',
      'entries': [
        {
          'lemma': 'shut',
          'language': 'en',
          'part_of_speech': 'verb',
          'definitions': [
            {'text': 'To close something.', 'examples': <String>[]},
          ],
        },
        {
          'lemma': 'shut off',
          'language': 'en',
          'part_of_speech': 'phrasal verb',
          'definitions': [
            {
              'text': 'To stop operating or make something stop operating.',
              'examples': <String>[],
            },
          ],
        },
      ],
    });

    expect(
      result.entries.map((entry) => entry.lemma),
      orderedEquals(['shut', 'shut off']),
    );
  });

  test('result rejects unknown statuses', () {
    expect(
      () => DictionaryLookupResult.fromJson({
        'request_id': 'request-1',
        'status': 'maybe',
        'term': 'power',
        'entries': const [],
      }),
      throwsFormatException,
    );
  });
}
