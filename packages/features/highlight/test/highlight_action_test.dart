import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/src/highlight_action.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_highlight_repository.dart';

const _selection = TextSelectionContext(
  selectedText: 'Important passage',
  sourceId: 'book-1',
  sourceType: SourceType.book,
  cfiRange: 'epubcfi(/6/4)',
  pageNumber: 12,
  scrollOffset: 0.5,
  progress: 0.42,
  chapterTitle: 'Chapter 4',
);

const _selectionOverlappingHighlights = TextSelectionContext(
  selectedText: 'longer passage that',
  sourceId: 'book-1',
  sourceType: SourceType.book,
  cfiRange: 'epubcfi(/6/4!/4/2,/1:10,/1:29)',
  progress: 0.42,
  chapterTitle: 'Chapter 4',
  highlightMerge: HighlightMergeTarget(
    cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:40)',
    text: 'Important longer passage that matters',
    highlightIds: ['h-left', 'h-right'],
  ),
);

void main() {
  group('HighlightAction', () {
    late FakeHighlightRepository repository;
    late HighlightAction action;

    setUp(() {
      repository = FakeHighlightRepository();
      action = HighlightAction(highlightRepository: repository);
    });

    test('label is Highlight', () {
      expect(action.label, 'Highlight');
    });

    test('icon is AppIcons.highlight', () {
      expect(action.icon, AppIcons.highlight);
    });

    testWidgets('saves default yellow highlight', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await action.onExecute(buildContext, _selection);

      expect(repository.highlights, hasLength(1));
      final highlight = repository.highlights.single;
      expect(highlight.text, 'Important passage');
      expect(highlight.sourceId, 'book-1');
      expect(highlight.sourceType, SourceType.book);
      expect(highlight.cfiRange, 'epubcfi(/6/4)');
      expect(highlight.pageNumber, 12);
      expect(highlight.scrollOffset, 0.5);
      expect(highlight.progress, 0.42);
      expect(highlight.chapterTitle, 'Chapter 4');
      expect(highlight.color, HighlightColor.yellow);
    });

    testWidgets('saves caller-selected highlight color', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await action.onExecuteWithColor(
        buildContext,
        _selection,
        HighlightColor.green,
      );

      expect(repository.highlights.single.color, HighlightColor.green);
    });

    testWidgets('saves the merged range and absorbs overlapping highlights', (
      tester,
    ) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await action.onExecuteWithColor(
        buildContext,
        _selectionOverlappingHighlights,
        HighlightColor.blue,
      );

      expect(repository.replacedHighlightIds, ['h-left', 'h-right']);
      final saved = repository.highlights.single;
      expect(saved.text, 'Important longer passage that matters');
      expect(saved.cfiRange, 'epubcfi(/6/4!/4/2,/1:0,/1:40)');
      expect(saved.color, HighlightColor.blue);
      // Location metadata still describes where the user selected.
      expect(saved.progress, 0.42);
      expect(saved.chapterTitle, 'Chapter 4');
    });

    testWidgets('a plain selection replaces nothing', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await action.onExecute(buildContext, _selection);

      expect(repository.replacedHighlightIds, isEmpty);
      expect(repository.highlights.single.cfiRange, 'epubcfi(/6/4)');
    });
  });
}
