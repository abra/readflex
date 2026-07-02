import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_image_highlight_cubit.dart';
import 'package:reader_webview/reader_webview.dart';

import 'helpers/fake_highlight_repository.dart';

void main() {
  group('ReaderImageHighlightCubit', () {
    late FakeHighlightRepository repository;
    late ReaderImageHighlightCubit cubit;

    setUp(() {
      repository = FakeHighlightRepository();
      cubit = ReaderImageHighlightCubit(highlightRepository: repository);
    });

    tearDown(() => cubit.close());

    test('saves image-area highlight with normalized note', () async {
      await cubit.save(
        sourceId: 'comic-1',
        sourceType: SourceType.book,
        pageIndex: 2,
        rect: const ReaderImageAreaRect(
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
        ),
        color: HighlightColor.green,
        note: '  Important panel  ',
        progress: 0.25,
        chapterTitle: '0003.jpg',
      );

      final highlight = repository.imageAreaHighlights.single;
      expect(highlight.note, 'Important panel');
      expect(highlight.imageArea!.pageIndex, 2);
      expect(highlight.color, HighlightColor.green);
      expect(highlight.progress, 0.25);
      expect(highlight.chapterTitle, '0003.jpg');
      expect(cubit.state.status, ReaderImageHighlightStatus.idle);
    });

    test('stores blank image-area notes as null', () async {
      await cubit.save(
        sourceId: 'comic-1',
        sourceType: SourceType.book,
        pageIndex: 0,
        rect: const ReaderImageAreaRect(
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
        ),
        color: HighlightColor.yellow,
        note: '   ',
      );

      expect(repository.imageAreaHighlights.single.note, isNull);
    });
  });
}
