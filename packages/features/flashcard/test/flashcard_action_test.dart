import 'package:component_library/component_library.dart';
import 'package:flashcard/src/flashcard_action.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFlashcardRepository implements FlashcardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FlashcardAction', () {
    late FlashcardAction action;

    setUp(() {
      action = FlashcardAction(
        flashcardRepository: _FakeFlashcardRepository(),
      );
    });

    test('label is Flashcard', () {
      expect(action.label, 'Flashcard');
    });

    test('icon is AppIcons.flashcard', () {
      expect(action.icon, AppIcons.flashcard);
    });
  });
}
