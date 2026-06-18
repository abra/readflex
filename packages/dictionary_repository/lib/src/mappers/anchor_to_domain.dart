import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _anchorEpoch = DateTime.fromMillisecondsSinceEpoch(0);

extension AnchorToDomain on DictionaryAnchorsTableData {
  DictionaryAnchor toDomainModel() => DictionaryAnchor(
    id: id,
    entryId: entryId,
    sourceId: sourceId,
    sourceType: SourceType.from(sourceType),
    text: anchorText,
    context: context,
    cfiRange: cfiRange,
    kind: DictionaryAnchorKind.from(kind),
    createdAt: DateTime.tryParse(createdAt) ?? _anchorEpoch,
  );
}
