import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evicts the least recently used entry at capacity', () {
    final cache = MemoryContextualTranslationCache(maxEntries: 2);
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

  test('expires entries after the configured ttl', () {
    var now = DateTime.utc(2026, 1, 1);
    final cache = MemoryContextualTranslationCache(
      ttl: const Duration(minutes: 5),
      clock: () => now,
    );
    final request = _request('hello');
    cache.write(request, _result(request));

    now = now.add(const Duration(minutes: 4));
    expect(cache.read(request), isNotNull);

    now = now.add(const Duration(minutes: 1));
    expect(cache.read(request), isNull);
  });
}

ContextualTranslationRequest _request(String text) {
  return ContextualTranslationRequest(
    requestId: 'request-$text',
    sourceLanguage: 'en',
    targetLanguage: 'ru',
    selection: TranslationSelection(text: text),
    context: TranslationTextContext(
      level: 'selection',
      current: TranslationContextPassage(text: text),
    ),
    anchor: const TranslationAnchor(sourceId: 'source-1', sourceType: 'book'),
  );
}

ContextualTranslationResult _result(ContextualTranslationRequest request) {
  return ContextualTranslationResult(
    requestId: request.requestId,
    status: ContextualTranslationStatus.resolved,
    reliability: ContextualTranslationReliability.verified,
    translation: ContextualTranslationText(
      contextualTranslation: request.selection.effectiveText,
    ),
  );
}
