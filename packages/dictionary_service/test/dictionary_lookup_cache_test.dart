import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evicts the least recently used entry at capacity', () {
    final cache = MemoryDictionaryLookupCache(maxEntries: 2);
    final first = _request('first');
    final second = _request('second');
    final third = _request('third');

    cache.write(first, _result(first));
    cache.write(second, _result(second));
    expect(cache.read(first), isNotNull);

    cache.write(third, _result(third));

    expect(cache.read(first), isNotNull);
    expect(cache.read(second), isNull);
    expect(cache.read(third), isNotNull);
  });

  test('rewriting a key refreshes its age and recency', () {
    var now = DateTime.utc(2026, 1, 1);
    final cache = MemoryDictionaryLookupCache(
      maxEntries: 2,
      ttl: const Duration(minutes: 5),
      clock: () => now,
    );
    final first = _request('first');
    final second = _request('second');
    cache.write(first, _result(first));
    cache.write(second, _result(second));

    now = now.add(const Duration(minutes: 4));
    cache.write(first, _result(first));
    cache.write(_request('third'), _result(_request('third')));

    expect(cache.read(second), isNull, reason: 'second is least recent');
    now = now.add(const Duration(minutes: 4));
    expect(cache.read(first), isNotNull, reason: 'rewritten 4 minutes ago');
  });

  test('expires entries after the configured ttl', () {
    var now = DateTime.utc(2026, 1, 1);
    final cache = MemoryDictionaryLookupCache(
      ttl: const Duration(minutes: 5),
      clock: () => now,
    );
    final request = _request('power');
    cache.write(request, _result(request));

    now = now.add(const Duration(minutes: 4));
    expect(cache.read(request), isNotNull);

    now = now.add(const Duration(minutes: 1));
    expect(cache.read(request), isNull);
  });

  test('defaults match the translation cache policy', () {
    final cache = MemoryDictionaryLookupCache();

    expect(cache.maxEntries, 128);
    expect(cache.ttl, const Duration(minutes: 30));
  });

  test('keys ignore the request ID but not the question', () {
    final cache = MemoryDictionaryLookupCache();
    final request = _request('power', requestId: 'first');
    cache.write(request, _result(request));

    expect(cache.read(_request('power', requestId: 'second')), isNotNull);
    expect(cache.read(_request('powers')), isNull);
    expect(cache.read(_request('power', sourceLanguage: 'de')), isNull);
    expect(
      cache.read(_request('power', contextText: 'Other [[power]].')),
      isNull,
    );
  });
}

DictionaryLookupRequest _request(
  String term, {
  String? requestId,
  String sourceLanguage = 'en',
  String contextText = 'The [[power]] bank.',
}) {
  return DictionaryLookupRequest(
    requestId: requestId ?? 'request-$term',
    term: term,
    sourceLanguage: sourceLanguage,
    contextText: contextText,
  );
}

DictionaryLookupResult _result(DictionaryLookupRequest request) {
  return DictionaryLookupResult(
    requestId: request.requestId,
    status: DictionaryLookupStatus.found,
    term: request.term,
    entries: [
      DictionaryLexicalEntry(
        lemma: request.term,
        definitions: const [DictionaryDefinition(text: 'Meaning.')],
      ),
    ],
  );
}
