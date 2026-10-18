import 'dictionary_models.dart';

abstract interface class DictionaryLookupCache {
  DictionaryLookupResult? read(DictionaryLookupRequest request);

  void write(DictionaryLookupRequest request, DictionaryLookupResult result);
}

class MemoryDictionaryLookupCache implements DictionaryLookupCache {
  MemoryDictionaryLookupCache({
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
  DictionaryLookupResult? read(DictionaryLookupRequest request) {
    final key = request.toCacheKey();
    final entry = _items.remove(key);
    if (entry == null) return null;
    if (_clock().difference(entry.writtenAt) >= ttl) return null;

    _items[key] = entry;
    return entry.result;
  }

  @override
  void write(DictionaryLookupRequest request, DictionaryLookupResult result) {
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

  final DictionaryLookupResult result;
  final DateTime writtenAt;
}
