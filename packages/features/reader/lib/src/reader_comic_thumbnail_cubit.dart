import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef ComicThumbnailLoader = Future<Uint8List?> Function(int page);

/// Drawer-local cache. Only mounted tiles request work; closing it releases both
/// encoded previews and their decoded Flutter image-cache entries.
class ReaderComicThumbnailCubit extends Cubit<Map<int, Uint8List?>> {
  ReaderComicThumbnailCubit(this._load) : super(const {});

  static const cacheCapacity = 24;
  final ComicThumbnailLoader _load;
  final _cache = <int, Uint8List?>{};
  // Several saved areas can share a page; each mounted preview owns one lease.
  final _wanted = <int, int>{};
  final _pending = <int>{};
  bool _running = false;

  void request(int page) {
    if (isClosed) return;
    _wanted.update(page, (count) => count + 1, ifAbsent: () => 1);
    if (_cache.containsKey(page)) {
      final value = _cache.remove(page);
      _cache[page] = value;
      return;
    }
    _pending.add(page);
    unawaited(_drain());
  }

  void release(int page) {
    final count = _wanted[page];
    if (count == null) return;
    if (count > 1) {
      _wanted[page] = count - 1;
      return;
    }
    _wanted.remove(page);
    _pending.remove(page);
  }

  void retry(int page) {
    if (isClosed ||
        !_wanted.containsKey(page) ||
        !_cache.containsKey(page) ||
        _cache[page] != null) {
      return;
    }
    _cache.remove(page);
    emit(Map.unmodifiable(_cache));
    _pending.add(page);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (!isClosed && _pending.isNotEmpty) {
        final page = _pending.first;
        _pending.remove(page);
        Uint8List? bytes;
        try {
          bytes = await _load(page);
          if (bytes != null && bytes.length > 96 * 1024) bytes = null;
        } catch (_) {
          // Preview errors have a local retry; they are not reader failures.
        }
        if (isClosed) return;
        // A repeated request while decoding must not enqueue the same page.
        _pending.remove(page);
        if (!_wanted.containsKey(page)) continue;
        _cache[page] = bytes;
        while (_cache.length > cacheCapacity) {
          final evicted = _cache.remove(_cache.keys.first);
          if (evicted != null) unawaited(MemoryImage(evicted).evict());
        }
        emit(Map.unmodifiable(_cache));
      }
    } finally {
      _running = false;
    }
  }

  @override
  Future<void> close() {
    _wanted.clear();
    _pending.clear();
    for (final bytes in _cache.values) {
      if (bytes != null) unawaited(MemoryImage(bytes).evict());
    }
    _cache.clear();
    return super.close();
  }
}
