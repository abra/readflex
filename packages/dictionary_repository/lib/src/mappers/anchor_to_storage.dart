import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension AnchorToStorage on DictionaryAnchor {
  DictionaryAnchorsTableCompanion toStorageModel() =>
      DictionaryAnchorsTableCompanion(
        id: Value(id),
        entryId: Value(entryId),
        sourceId: Value(sourceId),
        sourceType: Value(sourceType.name),
        anchorText: Value(text),
        context: Value(context),
        cfiRange: Value(cfiRange),
        kind: Value(kind.name),
        createdAt: Value(createdAt.toIso8601String()),
      );
}
