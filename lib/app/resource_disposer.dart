import 'dart:async';

import 'package:monitoring/monitoring.dart';

typedef ResourceDisposeCallback = FutureOr<void> Function();

/// Owns application resources and releases them in reverse creation order.
class ResourceDisposer {
  ResourceDisposer({required Logger logger}) : _logger = logger;

  final Logger _logger;
  final List<_ResourceDisposal> _resources = [];

  Future<void>? _disposeFuture;

  void add(
    String name,
    ResourceDisposeCallback callback, {
    bool disposeOnRollback = true,
  }) {
    if (_disposeFuture != null) {
      throw StateError('Cannot add $name after resource disposal has started.');
    }

    _resources.add(
      _ResourceDisposal(
        name: name,
        callback: callback,
        disposeOnRollback: disposeOnRollback,
      ),
    );
  }

  /// Releases all registered resources exactly once.
  ///
  /// When [rollback] is true, externally owned resources are retained so the
  /// caller can reuse them for a bootstrap retry.
  Future<void> dispose({bool rollback = false}) =>
      _disposeFuture ??= _disposeResources(rollback: rollback);

  Future<void> _disposeResources({required bool rollback}) async {
    for (final resource in _resources.reversed) {
      if (rollback && !resource.disposeOnRollback) continue;

      try {
        await resource.callback();
      } on Object catch (error, stackTrace) {
        _logger.warn(
          '${resource.name} failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

class _ResourceDisposal {
  const _ResourceDisposal({
    required this.name,
    required this.callback,
    required this.disposeOnRollback,
  });

  final String name;
  final ResourceDisposeCallback callback;
  final bool disposeOnRollback;
}
