import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArticleBlock', () {
    test('parses known block types', () {
      expect(
        ArticleBlock.fromJson({'type': 'heading', 'level': 9, 'text': 'Title'}),
        const ArticleHeadingBlock(level: 6, text: 'Title'),
      );
      expect(
        ArticleBlock.fromJson({
          'type': 'table',
          'rows': [
            ['A', 1],
          ],
        }),
        const ArticleTableBlock(
          rows: [
            ['A', '1'],
          ],
        ),
      );
    });

    test('preserves unknown blocks as fallback text', () {
      final block = ArticleBlock.fromJson({
        'type': 'callout',
        'text': 'Keep this',
        'severity': 'info',
      });

      expect(block, isA<ArticleUnknownBlock>());
      expect(block.fallbackText, 'Keep this');
      expect((block as ArticleUnknownBlock).rawJson, contains('severity'));
    });
  });
}
