import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_image_highlight_cubit.dart';
import 'package:reader/src/reader_selection.dart';

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
      final saved = await cubit.save(
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
      expect(saved, isTrue);
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

    Future<bool> save() => cubit.save(
      sourceId: 'comic',
      sourceType: SourceType.book,
      pageIndex: 0,
      rect: const ReaderImageAreaRect(x: .1, y: .2, width: .3, height: .4),
      color: HighlightColor.yellow,
    );

    test('busy rejects a second request without a second write', () async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      repository.addGate = gate.future;
      final accepted = save();
      expect(cubit.state.status, ReaderImageHighlightStatus.saving);
      expect(await save(), isFalse);
      gate.complete();
      expect(await accepted, isTrue);
      expect(repository.imageAreaHighlights, hasLength(1));
      expect(cubit.state.status, ReaderImageHighlightStatus.idle);
    });

    test(
      'closed cubit rejects a request without touching the repository',
      () async {
        await cubit.close();
        expect(await save(), isFalse);
        expect(repository.imageAreaHighlights, isEmpty);
      },
    );

    test(
      'a successful accepted write reports true even after closing',
      () async {
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        repository.addGate = gate.future;
        final accepted = save();
        await cubit.close();
        gate.complete();
        expect(await accepted, isTrue);
        expect(repository.imageAreaHighlights, hasLength(1));
        expect(cubit.isClosed, isTrue);
      },
    );

    test('repository failure propagates and restores the idle state', () async {
      repository.shouldThrow = true;
      await expectLater(save(), throwsException);
      expect(cubit.state.status, ReaderImageHighlightStatus.idle);
      expect(repository.imageAreaHighlights, isEmpty);
      repository.shouldThrow = false;
      expect(await save(), isTrue);
    });
  });
}
