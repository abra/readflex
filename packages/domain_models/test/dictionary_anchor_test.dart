import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DictionaryAnchor', () {
    test('stores source anchor metadata', () {
      final createdAt = DateTime(2026, 1, 1);
      final anchor = DictionaryAnchor(
        id: 'da-1',
        entryId: 'de-1',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        text: 'evening',
        context: 'Good [[evening]].',
        cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:7)',
        kind: DictionaryAnchorKind.normalizedSelection,
        createdAt: createdAt,
      );

      expect(anchor.entryId, 'de-1');
      expect(anchor.sourceType, SourceType.book);
      expect(anchor.kind, DictionaryAnchorKind.normalizedSelection);
      expect(anchor.createdAt, createdAt);
    });

    test('DictionaryAnchorKind.from falls back to exact selection', () {
      expect(
        DictionaryAnchorKind.from('normalizedSelection'),
        DictionaryAnchorKind.normalizedSelection,
      );
      expect(
        DictionaryAnchorKind.from('unknown'),
        DictionaryAnchorKind.exactSelection,
      );
    });
  });
}
