import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/src/highlight_action.dart';
import 'package:highlight_repository/highlight_repository.dart';

class _FakeHighlightRepository implements HighlightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HighlightAction', () {
    late HighlightAction action;

    setUp(() {
      action = HighlightAction(
        highlightRepository: _FakeHighlightRepository(),
      );
    });

    test('label is Highlight', () {
      expect(action.label, 'Highlight');
    });

    test('icon is AppIcons.highlight', () {
      expect(action.icon, AppIcons.highlight);
    });
  });
}
