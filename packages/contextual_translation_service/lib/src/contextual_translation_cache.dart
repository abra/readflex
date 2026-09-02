import 'contextual_translation_models.dart';

abstract class ContextualTranslationCache {
  ContextualTranslationResult? read(ContextualTranslationRequest request);

  void write(
    ContextualTranslationRequest request,
    ContextualTranslationResult result,
  );
}

class MemoryContextualTranslationCache implements ContextualTranslationCache {
  MemoryContextualTranslationCache({
    this.maxEntries = 128,
    this.ttl = const Duration(minutes: 30),
    DateTime Function()? clock,
  }) : assert(maxEntries > 0),
       assert(ttl > Duration.zero),
       _clock = clock ?? DateTime.now;

  final int maxEntries;
  final Duration ttl;
  final DateTime Function() _clock;
  final _items = <String, _CacheEntry>{};

  @override
  ContextualTranslationResult? read(ContextualTranslationRequest request) {
    final key = request.toCacheKey();
    final entry = _items.remove(key);
    if (entry == null) return null;
    if (_clock().difference(entry.writtenAt) >= ttl) return null;

    _items[key] = entry;
    return entry.result;
  }

  @override
  void write(
    ContextualTranslationRequest request,
    ContextualTranslationResult result,
  ) {
    final key = request.toCacheKey();
    _items.remove(key);
    _items[key] = _CacheEntry(result: result, writtenAt: _clock());
    while (_items.length > maxEntries) {
      _items.remove(_items.keys.first);
    }
  }
}

class _CacheEntry {
  const _CacheEntry({required this.result, required this.writtenAt});

  final ContextualTranslationResult result;
  final DateTime writtenAt;
}
