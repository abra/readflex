import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Answers a page's preview image, or null when none can be made.
///
/// The WebView reader answers with a `MemoryImage` of a small encoded
/// preview; the native engine answers with its own provider decoded at
/// preview width. Either way the framework's image cache holds the pixels.
typedef PageThumbnailLoader = Future<ImageProvider?> Function(int page);

/// Drawer-local cache. Only mounted tiles request work; closing it releases both
/// the providers and their decoded Flutter image-cache entries.
class ReaderPageThumbnailCubit extends Cubit<Map<int, ImageProvider?>> {
  ReaderPageThumbnailCubit(this._load) : super(const {});

  static const cacheCapacity = 24;
  final PageThumbnailLoader _load;
  final _cache = <int, ImageProvider?>{};
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
        ImageProvider? image;
        try {
          image = await _load(page);
        } catch (_) {
          // Preview errors have a local retry; they are not reader failures.
        }
        if (isClosed) return;
        // A repeated request while decoding must not enqueue the same page.
        _pending.remove(page);
        if (!_wanted.containsKey(page)) continue;
        _cache[page] = image;
        while (_cache.length > cacheCapacity) {
          final evicted = _cache.remove(_cache.keys.first);
          if (evicted != null) unawaited(evicted.evict());
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
    for (final image in _cache.values) {
      if (image != null) unawaited(image.evict());
    }
    _cache.clear();
    return super.close();
  }
}
