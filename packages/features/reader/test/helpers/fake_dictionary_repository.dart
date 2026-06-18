import 'dart:async';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final _changes = StreamController<void>.broadcast(sync: true);
  final Map<String, List<DictionaryAnchor>> anchorsBySourceId = {};
  bool shouldThrow = false;

  @override
  Stream<void> get changes => _changes.stream;

  void seedAnchors(String sourceId, List<DictionaryAnchor> anchors) {
    anchorsBySourceId[sourceId] = anchors;
    _changes.add(null);
  }

  @override
  Future<List<DictionaryAnchor>> getAnchorsBySource(String sourceId) async {
    if (shouldThrow) throw Exception('getAnchorsBySource failed');
    return anchorsBySourceId[sourceId] ?? [];
  }

  @override
  Future<void> dispose() => _changes.close();
}
