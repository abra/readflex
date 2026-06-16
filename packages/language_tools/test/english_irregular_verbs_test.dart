import 'package:language_tools/language_tools.dart';
import 'package:test/test.dart';

void main() {
  group('findEnglishIrregularVerbForms', () {
    test('finds a base form', () {
      final forms = findEnglishIrregularVerbForms('go');
      expect(forms?.base, 'go');
      expect(forms?.pastSimpleLabel, 'went');
      expect(forms?.pastParticipleLabel, 'gone');
    });

    test('finds past and participle forms', () {
      expect(findEnglishIrregularVerbForms('went')?.base, 'go');
      expect(findEnglishIrregularVerbForms('gone')?.base, 'go');
    });

    test('finds the verb inside a phrasal construction', () {
      final forms = findEnglishIrregularVerbForms('taken off');
      expect(forms?.base, 'take');
      expect(forms?.pastSimpleLabel, 'took');
      expect(forms?.pastParticipleLabel, 'taken');
    });

    test('returns null for regular verbs', () {
      expect(findEnglishIrregularVerbForms('looked up'), isNull);
    });
  });

  group('looksLikeVerbPartOfSpeech', () {
    test('recognizes verb labels', () {
      expect(looksLikeVerbPartOfSpeech('verb'), isTrue);
      expect(looksLikeVerbPartOfSpeech('phrasal verb'), isTrue);
    });

    test('rejects non-verb labels', () {
      expect(looksLikeVerbPartOfSpeech('noun'), isFalse);
      expect(looksLikeVerbPartOfSpeech(null), isFalse);
    });
  });
}
