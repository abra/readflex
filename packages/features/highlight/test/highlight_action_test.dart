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
  });
}
