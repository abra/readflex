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
