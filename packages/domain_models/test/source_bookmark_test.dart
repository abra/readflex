import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SourceBookmark uses value equality', () {
    final createdAt = DateTime(2026, 5, 17);
    final bookmark = SourceBookmark(
      id: 'bookmark-1',
      sourceId: 'source-1',
      sourceType: SourceType.book,
      cfi: 'epubcfi(/6/4)',
      content: 'Interesting page',
      progress: 0.42,
      chapterTitle: 'Chapter 7',
      createdAt: createdAt,
    );

    expect(
      bookmark,
      SourceBookmark(
        id: 'bookmark-1',
        sourceId: 'source-1',
        sourceType: SourceType.book,
        cfi: 'epubcfi(/6/4)',
        content: 'Interesting page',
        progress: 0.42,
        chapterTitle: 'Chapter 7',
        createdAt: createdAt,
      ),
    );
  });
}
