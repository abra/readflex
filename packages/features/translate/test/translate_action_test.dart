import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translate/src/translate_action.dart';
import 'package:translation_service/translation_service.dart';

class _FakeTranslationService implements TranslationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TranslateAction', () {
    late TranslateAction action;

    setUp(() {
      action = TranslateAction(
        translationService: _FakeTranslationService(),
        dictionaryRepository: _FakeDictionaryRepository(),
      );
    });

    test('label is Translate', () {
      expect(action.label, 'Translate');
    });

    test('icon is AppIcons.translate', () {
      expect(action.icon, AppIcons.translate);
    });
  });
}
