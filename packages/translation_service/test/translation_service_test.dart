import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:translation_service/translation_service.dart';

/// Builds a throw-away SQLite database matching the bundled pair-pack schema.
Future<Uint8List> _buildTranslationFixture() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'translation_fixture_',
  );
  final dbPath = p.join(tempDir.path, 'fixture.sqlite');
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  await db.execute('''
    CREATE TABLE entries (
      id INTEGER PRIMARY KEY,
      source_text TEXT NOT NULL,
      normalized_source_text TEXT NOT NULL,
      source_language_code TEXT NOT NULL,
      UNIQUE (source_language_code, normalized_source_text)
    );
  ''');
  await db.execute('''
    CREATE TABLE translations (
      id INTEGER PRIMARY KEY,
      entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
      target_language_code TEXT NOT NULL,
      translated_text TEXT NOT NULL,
      normalized_translated_text TEXT NOT NULL,
      source TEXT NOT NULL,
      confidence REAL,
      quality_status TEXT NOT NULL,
      part_of_speech TEXT,
      sense TEXT,
      romanization TEXT,
      transcription TEXT,
      tags_json TEXT NOT NULL,
      examples_json TEXT NOT NULL,
      metadata_json TEXT NOT NULL,
      dedupe_key TEXT NOT NULL,
      UNIQUE (entry_id, target_language_code, source, dedupe_key)
    );
  ''');
  await db.insert('entries', {
    'id': 1,
    'source_text': 'hello',
    'normalized_source_text': 'hello',
    'source_language_code': 'en',
  });
  await db.insert('translations', {
    'entry_id': 1,
    'target_language_code': 'ru',
    'translated_text': 'приве́т',
    'normalized_translated_text': 'привет',
    'source': 'kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Hello there."]',
    'metadata_json': '{}',
    'dedupe_key': 'ru:привет',
  });
  await db.insert('translations', {
    'entry_id': 1,
    'target_language_code': 'ru',
    'translated_text': 'здра́вствуй',
    'normalized_translated_text': 'здравствуй',
    'source': 'kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Hello there."]',
    'metadata_json': '{}',
    'dedupe_key': 'ru:здравствуй',
  });
  await db.insert('entries', {
    'id': 2,
    'source_text': 'привет',
    'normalized_source_text': 'привет',
    'source_language_code': 'ru',
  });
  await db.insert('translations', {
    'entry_id': 2,
    'target_language_code': 'en',
    'translated_text': 'hello',
    'normalized_translated_text': 'hello',
    'source': 'reverse_kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Привет всем."]',
    'metadata_json': '{"reversed":true}',
    'dedupe_key': 'en:hello',
  });
  await db.insert('translations', {
    'entry_id': 2,
    'target_language_code': 'en',
    'translated_text': 'hi',
    'normalized_translated_text': 'hi',
    'source': 'reverse_kaikki_native',
    'confidence': null,
    'quality_status': 'native',
    'part_of_speech': 'interjection',
    'sense': 'greeting',
    'romanization': null,
    'transcription': null,
    'tags_json': '[]',
    'examples_json': '["Привет всем."]',
    'metadata_json': '{"reversed":true}',
    'dedupe_key': 'en:hi',
  });
  await db.close();

  final bytes = await File(dbPath).readAsBytes();
  await tempDir.delete(recursive: true);
  return bytes;
}

class _FakeOnDeviceTranslationClient implements OnDeviceTranslationClient {
  _FakeOnDeviceTranslationClient({this.result});

  final String? result;
  var calls = 0;
  String? lastContextText;
  var disposed = false;

  @override
  Future<String?> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    calls += 1;
    lastContextText = contextText;
    return result;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _FakeRemoteTranslationClient implements RemoteTranslationClient {
  _FakeRemoteTranslationClient({this.result});

  final TranslationResult? result;
  var calls = 0;
  String? lastContextText;
  var disposed = false;

  @override
  Future<TranslationResult?> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    calls += 1;
    lastContextText = contextText;
    return result;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('DeepSeekDirectTranslationClient', () {
    test('keeps source and target definitions structured', () {
      final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
        jsonEncode({
          'translated_text': 'использовать',
          'expression': null,
          'sense': {
            'source_definition':
                'To use something effectively to achieve a result.',
            'target_definition':
                'Использовать что-либо как средство для достижения результата.',
            'source_context_note':
                'The sentence uses lever as a verb, not as the noun lever.',
            'target_context_note':
                'В этом контексте подходит глагол «использовать», а не существительное «рычаг».',
          },
          'context': 'legacy context should not win',
          'usage_examples': ['They [[lever]] their network.'],
        }),
        originalText: 'lever',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );

      expect(result, isNotNull);
      expect(result!.translatedText, 'использовать');
      expect(result.context, isNull);
      expect(
        result.sense!.sourceDefinition,
        'To use something effectively to achieve a result.',
      );
      expect(
        result.sense!.targetDefinition,
        'Использовать что-либо как средство для достижения результата.',
      );
      expect(
        result.sense!.sourceContextNote,
        'The sentence uses lever as a verb, not as the noun lever.',
      );
      expect(
        result.sense!.targetContextNote,
        'В этом контексте подходит глагол «использовать», а не существительное «рычаг».',
      );
      expect(result.usageExamples, ['They [[lever]] their network.']);
    });

    test('parses span-aware schema fields from contextual responses', () {
      final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
        jsonEncode({
          'answer_type': 'expression_explanation',
          'term': 'things',
          'normalized_expression': 'kick off',
          'expression_type': 'separable_phrasal_verb',
          'is_multiword_expression': true,
          'part_of_speech': 'verb',
          'register': 'neutral',
          'domain': null,
          'confidence': 'medium',
          'translation': {'target': 'начать'},
          'definition': {
            'source': 'To start an activity or process.',
            'target': 'Начать действие, встречу или процесс.',
          },
          'context_explanation': {
            'source': 'Things is the object inserted into kick off.',
            'target':
                'Things является объектом внутри разделяемого фразового глагола.',
          },
          'expression': {
            'selected_text': 'things',
            'selected_role': 'object',
            'construction_type': 'separable_phrasal_verb',
            'surface': 'kick things off',
            'lexical_unit': 'kick off',
            'canonical_pattern': 'kick [object] off',
            'is_selected_part_of_lexical_unit': false,
          },
          'natural_equivalents': {
            'target': ['начать', 'запустить'],
          },
          'literal_translation': {'target': 'вещи'},
          'suggested_full_phrase': {
            'source': 'kick things off',
            'target': 'начать дело',
          },
          'examples': [
            {
              'source': 'Let us [[kick the meeting off]].',
              'target': 'Давайте начнем встречу.',
            },
          ],
          'notes': {
            'source': 'Things is not part of the lexical headword.',
            'target': 'Things не является частью словарной единицы.',
          },
        }),
        originalText: 'things',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );

      expect(result, isNotNull);
      expect(result!.translatedText, 'вещи');
      expect(result.answerType, TranslationAnswerType.expressionExplanation);
      expect(result.confidence, TranslationConfidence.medium);
      expect(result.expression!.term, 'things');
      expect(result.expression!.surface, 'kick things off');
      expect(result.expression!.lexicalUnit, 'kick off');
      expect(result.expression!.canonicalPattern, 'kick [object] off');
      expect(result.expression!.isSelectedPartOfLexicalUnit, isFalse);
      expect(
        result.sense!.sourceDefinition,
        'To start an activity or process.',
      );
      expect(result.naturalEquivalents, ['начать', 'запустить']);
      expect(result.literalTranslation, 'вещи');
      expect(
        result.suggestedFullPhrase,
        const TranslationTextPair(
          source: 'kick things off',
          target: 'начать дело',
        ),
      );
      expect(
        result.notes!.target,
        'Things не является частью словарной единицы.',
      );
      expect(result.usageExamples, ['Let us [[kick the meeting off]].']);
    });

    test(
      'repairs expression fields when the model only explains them in context notes',
      () {
        final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
          jsonEncode({
            'answer_type': 'word_translation',
            'translated_text': 'вне',
            'definition': {
              'source': 'Not in operation or unavailable for use.',
              'target':
                  'Не в рабочем состоянии или недоступен для использования.',
            },
            'context_explanation': {
              'source':
                  "In this context, 'out' is part of the phrase 'out of service', meaning the device is not functioning or unavailable.",
              'target':
                  "В данном контексте 'out' является частью фразы 'out of service', означающей, что устройство не функционирует или недоступно.",
            },
            'usage_examples': [
              'The system will be [[out of service]] for maintenance.',
            ],
          }),
          originalText: 'out',
          sourceLanguage: 'en',
          targetLanguage: 'ru',
        );

        expect(result, isNotNull);
        expect(result!.translatedText, 'вне');
        expect(result.answerType, TranslationAnswerType.expressionExplanation);
        expect(result.expression!.term, 'out');
        expect(result.expression!.surface, 'out of service');
        expect(result.expression!.lexicalUnit, 'out of service');
        expect(result.expression!.expressionType, 'fixed_expression');
        expect(
          result.suggestedFullPhrase,
          const TranslationTextPair(
            source: 'out of service',
            target: 'Не в рабочем состоянии или недоступен для использования.',
          ),
        );
      },
    );

    test('does not keep phrasal-verb metadata for non-verb expressions', () {
      final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
        jsonEncode({
          'answer_type': 'expression_explanation',
          'translated_text': 'вне',
          'expression': {
            'term': 'out',
            'surface': 'out of service',
            'lexical_unit': 'out of service',
            'expression_type': 'fixed_expression',
            'selected_role': 'particle',
            'canonical_pattern': 'out of service',
            'is_multiword_expression': true,
          },
          'definition': {
            'source':
                'A particle used with a verb to form a phrasal-verb construction.',
            'target':
                "Часть выражения 'out of service', означающего 'не функционирующий'.",
          },
          'context_explanation': {
            'source':
                "The selected text 'out' appears as the particle in 'out of service', with the pattern 'out of service'.",
            'target':
                "В данном контексте 'out' является частью фразы 'out of service'.",
          },
          'suggested_full_phrase': {
            'source': 'out of service',
            'target': 'вне эксплуатации',
          },
        }),
        originalText: 'out',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );

      expect(result, isNotNull);
      expect(result!.translatedText, 'вне');
      expect(result.expression!.surface, 'out of service');
      expect(result.expression!.expressionType, 'fixed_expression');
      expect(result.expression!.selectedRole, 'component');
      expect(result.expression!.canonicalPattern, isNull);
      expect(result.sense!.sourceDefinition, isNot(contains('phrasal')));
      expect(result.sense!.sourceDefinition, contains('out of service'));
      expect(result.sense!.sourceContextNote, isNot(contains('particle')));
      expect(result.sense!.sourceContextNote, contains('out of service'));
    });

    test('marks the selected span in surrounding context for the model', () {
      expect(
        DeepSeekDirectTranslationClient.markedContextForTesting(
          selectedText: 'lever',
          contextText: 'Teams lever feedback to improve the roadmap.',
        ),
        'Teams [[lever]] feedback to improve the roadmap.',
      );
      expect(
        DeepSeekDirectTranslationClient.markedContextForTesting(
          selectedText: 'Lever',
          contextText: 'Teams lever feedback to improve the roadmap.',
        ),
        'Teams [[lever]] feedback to improve the roadmap.',
      );
      expect(
        DeepSeekDirectTranslationClient.markedContextForTesting(
          selectedText: 'of',
          contextText: 'length of time; out [[of]] service',
        ),
        'length of time; out [[of]] service',
      );
      expect(
        DeepSeekDirectTranslationClient.markedContextForTesting(
          selectedText: 'in',
          contextText: 'Several users were interested in offline translation.',
        ),
        'Several users were interested [[in]] offline translation.',
      );
    });

    test(
      'payload declares source and target languages without UI language',
      () {
        final payload = DeepSeekDirectTranslationClient.payloadForTesting(
          text: 'kick',
          fromLang: 'en',
          toLang: 'ru',
          contextText: 'Kick things off.',
        );

        expect(payload['source_language'], 'en');
        expect(payload['source_language_name'], 'English');
        expect(payload['target_language'], 'ru');
        expect(payload['target_language_name'], 'Russian');
        expect(payload.containsKey('ui_language'), isFalse);
        expect(payload['marked_context'], '[[Kick]] things off.');
      },
    );

    test('payload keeps plain and marked context separate', () {
      final payload = DeepSeekDirectTranslationClient.payloadForTesting(
        text: 'of',
        fromLang: 'en',
        toLang: 'ru',
        contextText: 'length of time; out [[of]] service',
      );

      expect(payload['context_text'], 'length of time; out of service');
      expect(payload['marked_context'], 'length of time; out [[of]] service');
      expect(payload['context'], {'current': 'length of time; out of service'});
    });

    test('payload sends previous current and next sentence window', () {
      final payload = DeepSeekDirectTranslationClient.payloadForTesting(
        text: 'stakeholders',
        fromLang: 'en',
        toLang: 'ru',
        contextText:
            'rk will be directly affected by the principles. It may also be a good idea to open the process to design leadership and stakeholders outside of the immediate team, as they will bring a different perspective that is also valuable. The more people you can',
      );

      expect(
        payload['marked_context'],
        'rk will be directly affected by the principles. It may also be a good idea to open the process to design leadership and [[stakeholders]] outside of the immediate team, as they will bring a different perspective that is also valuable. The more people you can',
      );
      expect(
        payload['context_text'],
        'rk will be directly affected by the principles. It may also be a good idea to open the process to design leadership and stakeholders outside of the immediate team, as they will bring a different perspective that is also valuable. The more people you can',
      );
      expect(payload['context'], {
        'previous': 'rk will be directly affected by the principles.',
        'current':
            'It may also be a good idea to open the process to design leadership and stakeholders outside of the immediate team, as they will bring a different perspective that is also valuable.',
        'next': 'The more people you can',
      });
    });

    test('request payload disables thinking for V4 Pro translations', () {
      final userPayload = DeepSeekDirectTranslationClient.payloadForTesting(
        text: 'kick',
        fromLang: 'en',
        toLang: 'ru',
        contextText: 'Kick things off.',
      );

      final requestPayload =
          DeepSeekDirectTranslationClient.requestPayloadForTesting(
            userPayload: userPayload,
          );

      expect(requestPayload['model'], 'deepseek-v4-pro');
      expect(requestPayload['thinking'], {'type': 'disabled'});
      expect(requestPayload['max_tokens'], greaterThan(1200));
      expect(requestPayload['response_format'], {'type': 'json_object'});
    });

    test('prompt uses the minimal contextual response contract', () {
      final prompt = DeepSeekDirectTranslationClient.systemPromptForTesting;

      expect(prompt, contains('"mode": "word_in_expression"'));
      expect(prompt, contains('"mode": "single_word"'));
      expect(prompt, contains('"mode": "selected_expression"'));
      expect(prompt, contains('"mode": "span_translation"'));
      expect(prompt, contains('"word_translation"'));
      expect(prompt, contains('"marked_sentence"'));
      expect(prompt, contains('"usage_examples"'));
      expect(prompt, contains('"related_terms"'));
      expect(prompt, contains('context.previous/context.next'));
      expect(prompt, contains('usage_examples must stay in source_language'));
      expect(prompt, contains('related_terms are vocabulary aids'));
      expect(prompt, contains('not alternative translations'));
      expect(prompt, contains('not translation explanations'));
      expect(
        prompt,
        contains('word_family|domain_collocation|contrast_term'),
      );
      expect(prompt, contains('established source collocation'));
      expect(prompt, contains('Do not include synonyms, near-synonyms'));
      expect(prompt, contains('definition-derived phrases'));
      expect(prompt, contains('generic related concepts'));
      expect(prompt, contains('whose source repeats or contains'));
      expect(prompt, contains('selected headword'));
      expect(prompt, contains('vocabulary boundaries'));
      expect(prompt, isNot(contains('"similar"')));
      expect(prompt, contains('phrasal verb'));
      expect(prompt, contains('idiom'));
      expect(prompt, contains('fixed phrase'));
      expect(prompt, contains('collocation'));
      expect(prompt, contains('verb pattern'));
      expect(prompt, contains('preposition pattern'));
      expect(prompt, contains('sentence pattern'));
      expect(prompt, contains('learner-dictionary collocation'));
      expect(prompt, contains('selected heavy or rain in heavy rain'));
      expect(prompt, contains('selected deadline in meet a deadline'));
      expect(prompt, contains('selected crime in commit a crime'));
      expect(prompt, contains('selected more in the more I read'));
      expect(prompt, contains('phrase.text = "the more...the more"'));
      expect(prompt, contains('selected only or but in not only'));
      expect(prompt, contains('phrase.text = "not only...but also"'));
      expect(prompt, contains('Do not add keys outside'));
      expect(prompt, contains('Choose the response mode first'));
      expect(prompt, contains('Do not choose single_word until'));
      expect(prompt, contains('larger-unit checks below fail'));
      expect(prompt, contains('not a mode-selection rule'));
      expect(prompt, contains('Return single_word only when'));
      expect(prompt, contains('is not part of any larger unit'));
      expect(prompt, contains('including the semantic head'));
      expect(prompt, contains('ordinary standalone noun/verb/adjective'));
      expect(prompt, contains('English examples are illustrative only'));
      expect(prompt, contains('for every source_language and script'));
      expect(prompt, contains('languages without whitespace word boundaries'));
      expect(prompt, contains('selected night in a night out'));
      expect(prompt, contains('selected out in a night out'));
      expect(prompt, contains('selected way in out of the way'));
      expect(prompt, isNot(contains('Exact selection comes first')));
      expect(
        prompt.indexOf('Rules:'),
        lessThan(prompt.indexOf('If one selected word is part')),
      );
      expect(
        prompt.indexOf('Do not choose single_word until'),
        lessThan(prompt.indexOf('Return single_word only when')),
      );
      expect(prompt, contains('exact selected token'));
      expect(prompt, contains('not an unrelated homograph/part of speech'));
      expect(prompt, contains('before applying the larger-unit meaning'));
      expect(prompt, contains('selected carried in carried on'));
      expect(prompt, contains('not продолжал'));
      expect(prompt, contains('selected fading in fading out the top image'));
      expect(prompt, contains('not увядание'));
      expect(prompt, contains('slash-delimited IPA'));
      expect(prompt, contains('"word_form"'));
      expect(prompt, contains('singular noun'));
      expect(prompt, contains('singular slash-delimited IPA'));
      expect(prompt, contains('construction span to highlight'));
      expect(prompt, contains('Do not imply an inserted object is part'));
      expect(
        prompt,
        contains('should not translate only the verb plus object'),
      );
      expect(prompt, contains('looked at the term'));
      expect(prompt, contains('selected word is a lexical verb'));
      expect(prompt, contains('fading out'));
      expect(prompt, contains('phrase.text = "fading out"'));
      expect(prompt, contains('grammatical complete-sentence examples'));
      expect(prompt, contains('gerunds/present participles'));
      expect(prompt, contains('grammatical_form gerund'));
      expect(
        prompt,
        contains('concise contextual target-language translation'),
      );
      expect(prompt, contains('not an explanatory definition'));
      expect(prompt, contains('ordinary compositional descriptive spans'));
      expect(prompt, contains('new security review'));
      expect(prompt, contains('red leather notebook'));
      expect(prompt, isNot(contains('lexical_unit')));
      expect(prompt, isNot(contains('canonical_pattern')));
      expect(prompt, isNot(contains('selected_role')));
      expect(prompt, isNot(contains('natural_equivalents')));
    });

    test('decodes minimal one-word expression payload', () {
      final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
        jsonEncode({
          'mode': 'word_in_expression',
          'word': 'kick',
          'word_translation': 'пинать',
          'definition': {
            'source': 'To begin something in this expression.',
            'target': 'Начать что-то в этом выражении.',
          },
          'phrase': {
            'text': 'kick things off',
            'translation': 'начать дело',
            'type': 'phrasal_verb',
          },
          'marked_sentence':
              'Once the team is identified, it is time to [[kick things off]].',
        }),
        originalText: 'kick',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );

      expect(result, isNotNull);
      expect(result!.answerType, TranslationAnswerType.expressionExplanation);
      expect(result.translatedText, 'пинать');
      expect(result.expression!.surface, 'kick things off');
      expect(
        result.suggestedFullPhrase,
        const TranslationTextPair(
          source: 'kick things off',
          target: 'начать дело',
        ),
      );
      expect(result.usageExamples.single, contains('[[kick things off]]'));
    });

    test('keeps contextual phrase translation separate from definition', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'mode': 'word_in_expression',
              'word': 'burst',
              'word_translation': 'вспыхнуть',
              'definition': {
                'source': 'To enter suddenly and forcefully.',
                'target': 'Внезапно и с силой войти в помещение.',
              },
              'phrase': {
                'text': 'burst in',
                'translation': 'ворваться',
                'type': 'phrasal_verb',
              },
              'marked_sentence':
                  'Two cops [[burst in]] through the door at the back.',
            }),
            originalText: 'burst',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.translatedText, 'вспыхнуть');
      expect(
        result.sense!.targetDefinition,
        'Внезапно и с силой войти в помещение.',
      );
      expect(
        result.suggestedFullPhrase,
        const TranslationTextPair(source: 'burst in', target: 'ворваться'),
      );
    });

    test('decodes selected verb inside nearby phrasal particle payload', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'mode': 'word_in_expression',
              'word': 'fading',
              'word_translation': 'исчезновение',
              'word_form': {
                'lemma': 'fade',
                'form': 'gerund',
                'transcription': 'feɪd',
              },
              'definition': {
                'source': 'To gradually make something disappear from view.',
                'target': 'Постепенно скрыть что-либо из поля зрения.',
              },
              'phrase': {'text': 'fading out', 'type': 'phrasal_verb'},
              'marked_sentence':
                  'The image is revealed by [[fading out]] the top image.',
            }),
            originalText: 'fading',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.answerType, TranslationAnswerType.expressionExplanation);
      expect(result.translatedText, 'исчезновение');
      expect(result.expression!.surface, 'fading out');
      expect(result.sense!.lemma, 'fade');
      expect(result.sense!.lemmaTranscription, '/feɪd/');
      expect(result.sense!.grammaticalForm, 'gerund');
    });

    test('decodes minimal ordinary word payload', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'mode': 'single_word',
              'word': 'lever',
              'word_translation': 'рычаг',
              'part_of_speech': 'noun',
              'transcription': 'ˈliːvər',
              'definition': {
                'source': 'A rigid handle used to move or control something.',
                'target': 'Жесткая рукоятка для управления или движения.',
              },
              'marked_sentence': 'Pull the [[lever]] slowly.',
            }),
            originalText: 'lever',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.answerType, TranslationAnswerType.wordTranslation);
      expect(result.translatedText, 'рычаг');
      expect(result.expression, isNull);
      expect(result.sense!.partOfSpeech, 'noun');
      expect(result.sense!.transcription, '/ˈliːvər/');
      expect(result.sense!.sourceDefinition, startsWith('A rigid handle'));
      expect(result.usageExamples.single, 'Pull the [[lever]] slowly.');
    });

    test('decodes minimal usage variants and analogues', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'mode': 'single_word',
              'word': 'lever',
              'word_translation': 'рычаг',
              'part_of_speech': 'noun',
              'transcription': null,
              'definition': {
                'source': 'A handle used to move or control something.',
                'target': 'Рукоятка для управления или движения.',
              },
              'marked_sentence': 'Pull the [[lever]] slowly.',
              'usage_examples': [
                'She pushed the [[lever]] down.',
                'Use the [[lever]] to open the hatch.',
              ],
              'related_terms': [
                {
                  'source': 'handle',
                  'target': 'рукоятка',
                  'relation': 'narrower_domain_term',
                },
                {
                  'source': 'small lever',
                  'target': 'рычажок',
                  'relation': 'narrower_domain_term',
                },
                {
                  'source': 'control',
                  'target': 'управлять',
                  'relation': 'near_synonym',
                },
              ],
            }),
            originalText: 'lever',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.usageExamples, [
        'Pull the [[lever]] slowly.',
        'She pushed the [[lever]] down.',
        'Use the [[lever]] to open the hatch.',
      ]);
      expect(result.naturalEquivalents, ['handle — рукоятка']);
    });

    test('filters related terms that repeat the selected headword', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'mode': 'single_word',
              'word': 'stakeholders',
              'word_translation': 'заинтересованные стороны',
              'part_of_speech': 'noun',
              'word_form': {
                'lemma': 'stakeholder',
                'form': 'plural',
                'transcription': '/ˈsteɪkˌhoʊldər/',
              },
              'definition': {
                'source': 'People or groups with an interest in something.',
                'target': 'Люди или группы, заинтересованные в чем-либо.',
              },
              'marked_sentence': 'Leadership and [[stakeholders]] joined.',
              'related_terms': [
                {
                  'source': 'shareholder',
                  'target': 'акционер',
                  'relation': 'contrast_term',
                },
                {
                  'source': 'stakeholder analysis',
                  'target': 'анализ заинтересованных сторон',
                  'relation': 'domain_collocation',
                },
                {
                  'source': 'stakeholder engagement',
                  'target': 'взаимодействие с заинтересованными сторонами',
                  'relation': 'domain_collocation',
                },
              ],
            }),
            originalText: 'stakeholders',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.sense!.lemma, 'stakeholder');
      expect(result.sense!.grammaticalForm, 'plural');
      expect(result.sense!.lemmaTranscription, '/ˈsteɪkˌhoʊldər/');
      expect(result.naturalEquivalents, ['shareholder — акционер']);
    });

    test('filters related terms that repeat expression headwords', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'answer_type': 'expression_explanation',
              'translated_text': 'начать',
              'literal_translation': {'target': 'пнуть'},
              'expression': {
                'selected_text': 'kick',
                'selected_role': 'verb',
                'surface': 'kick things off',
                'lexical_unit': 'kick off',
                'canonical_pattern': 'kick [object] off',
              },
              'related_terms': [
                {
                  'source': 'kick off',
                  'target': 'начинать',
                  'relation': 'domain_collocation',
                },
                {
                  'source': 'kickoff',
                  'target': 'начало',
                  'relation': 'word_family',
                },
                {
                  'source': 'start',
                  'target': 'начинать',
                  'relation': 'near_synonym',
                },
              ],
            }),
            originalText: 'kick',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.naturalEquivalents, isEmpty);
    });

    test('uses literal selected text translation above expression meaning', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'answer_type': 'expression_explanation',
              'translated_text': 'начать',
              'literal_translation': {'target': 'пнуть'},
              'suggested_full_phrase': {
                'source': 'kick things off',
                'target': 'начать работу',
              },
              'expression': {
                'selected_text': 'kick',
                'selected_role': 'verb',
                'surface': 'kick things off',
                'lexical_unit': 'kick off',
                'canonical_pattern': 'kick [object] off',
                'is_selected_part_of_lexical_unit': true,
              },
            }),
            originalText: 'kick',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.translatedText, 'пнуть');
      expect(result.suggestedFullPhrase!.target, 'начать работу');
    });

    test('keeps kick translation literal but definitions contextual', () {
      final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
        jsonEncode({
          'answer_type': 'expression_explanation',
          'translated_text': 'пнуть',
          'sense': {
            'source_definition':
                'To start or launch something, especially an event or process.',
            'target_definition':
                'Начать или запустить что-либо, особенно событие или процесс.',
            'source_context_note':
                'Kick is part of kick things off, which means to start.',
            'target_context_note':
                'Kick является частью kick things off со значением начать.',
          },
          'expression': {
            'selected_text': 'kick',
            'selected_role': 'verb',
            'surface': 'kick things off',
            'lexical_unit': 'kick off',
            'canonical_pattern': 'kick [object] off',
          },
        }),
        originalText: 'kick',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );

      expect(result, isNotNull);
      expect(
        result!.sense!.sourceDefinition,
        'To start or launch something, especially an event or process.',
      );
      expect(
        result.sense!.targetDefinition,
        'Начать или запустить что-либо, особенно событие или процесс.',
      );
      expect(
        result.sense!.sourceContextNote,
        'Kick is part of kick things off, which means to start.',
      );
    });

    test(
      'restores source-side context when model localizes it to target language',
      () {
        final result =
            DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
              jsonEncode({
                'translated_text': 'с',
                'answer_type': 'expression_explanation',
                'sense': {
                  'source_definition':
                      'часть фразового глагола kick off, означающего начать',
                  'target_definition':
                      'часть фразового глагола kick off, означающего начать',
                  'source_context_note':
                      'слово off является частицей в kick things off',
                  'target_context_note':
                      'слово off является частицей в kick things off',
                },
                'expression': {
                  'selected_text': 'off',
                  'selected_role': 'particle',
                  'surface': 'kick things off',
                  'lexical_unit': 'kick off',
                  'canonical_pattern': 'kick [object] off',
                },
              }),
              originalText: 'off',
              sourceLanguage: 'en',
              targetLanguage: 'ru',
            );

        expect(result, isNotNull);
        expect(
          result!.sense!.sourceDefinition,
          'A particle used with a verb to form a phrasal-verb construction.',
        );
        expect(
          result.sense!.sourceContextNote,
          'The selected text "off" appears as the particle in "kick things off", whose lexical unit is "kick off", with the pattern "kick [object] off".',
        );
        expect(
          result.sense!.targetDefinition,
          'часть фразового глагола kick off, означающего начать',
        );
        expect(
          result.sense!.targetContextNote,
          'слово off является частицей в kick things off',
        );
      },
    );

    test('does not restore verb selections as phrasal particles', () {
      final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
        jsonEncode({
          'mode': 'word_in_expression',
          'word': 'kick',
          'word_translation': 'пинать',
          'definition': {
            'source': 'начать что-либо, инициировать процесс',
            'target': 'начать что-либо, инициировать процесс',
          },
          'phrase': {
            'text': 'kick things off',
            'type': 'phrasal_verb',
          },
          'marked_sentence':
              'It is time to [[kick things off]] by aligning on success criteria.',
        }),
        originalText: 'kick',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      );

      expect(result, isNotNull);
      expect(
        result!.sense!.sourceDefinition,
        'The selected text "kick" functions as part of the expression "kick things off" in this context.',
      );
      expect(
        result.sense!.sourceDefinition,
        isNot(contains('particle')),
      );
    });

    test('repairs phrase source and filters weak separable examples', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'answer_type': 'expression_explanation',
              'translated_text': 'прочь',
              'suggested_full_phrase': {'target': 'начать работу'},
              'expression': {
                'selected_text': 'off',
                'selected_role': 'particle',
                'surface': 'kick things off',
                'lexical_unit': 'kick off',
                'canonical_pattern': 'kick [object] off',
              },
              'usage_examples': [
                'Let us [[kick off]] the meeting.',
                'They [[kicked off]] the project.',
                'Let us [[kick the meeting off]] now.',
              ],
            }),
            originalText: 'off',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(
        result!.suggestedFullPhrase,
        const TranslationTextPair(
          source: 'kick things off',
          target: 'начать работу',
        ),
      );
      expect(result.usageExamples, ['Let us [[kick the meeting off]] now.']);
    });

    test('expands separated phrasal example highlight to full construction', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'answer_type': 'expression_explanation',
              'translated_text': 'пинать',
              'expression': {
                'selected_text': 'kick',
                'selected_role': 'verb',
                'surface': 'kick things off',
                'lexical_unit': 'kick off',
                'canonical_pattern': 'kick [something] off',
              },
              'usage_examples': [
                'They [[kicked]] the project off with a brainstorming session.',
              ],
            }),
            originalText: 'kick',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.usageExamples, [
        'They [[kicked the project off]] with a brainstorming session.',
      ]);
    });

    test('filters separated phrasal examples without word-specific logic', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'answer_type': 'expression_explanation',
              'translated_text': 'вниз',
              'expression': {
                'selected_text': 'down',
                'selected_role': 'particle',
                'surface': 'turn the offer down',
                'lexical_unit': 'turn down',
                'canonical_pattern': 'turn [object] down',
              },
              'usage_examples': [
                'Please [[turn down]] the offer.',
                'Please [[turn the offer down]] today.',
              ],
            }),
            originalText: 'down',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.usageExamples, [
        'Please [[turn the offer down]] today.',
      ]);
    });

    test('accepts inflected separated phrasal examples generically', () {
      final result =
          DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
            jsonEncode({
              'answer_type': 'expression_explanation',
              'translated_text': 'вверх',
              'expression': {
                'selected_text': 'up',
                'selected_role': 'particle',
                'surface': 'look the word up',
                'lexical_unit': 'look up',
                'canonical_pattern': 'look [object] up',
              },
              'usage_examples': [
                'She [[looked up]] the word.',
                'She [[looked the word up]] later.',
              ],
            }),
            originalText: 'up',
            sourceLanguage: 'en',
            targetLanguage: 'ru',
          );

      expect(result, isNotNull);
      expect(result!.usageExamples, [
        'She [[looked the word up]] later.',
      ]);
    });
  });

  group('NoopTranslationService', () {
    const service = NoopTranslationService();

    test('translate returns platform source with formatted text', () async {
      final result = await service.translate(
        'hello',
        fromLang: 'en',
        toLang: 'ru',
      );
      expect(result.originalText, 'hello');
      expect(result.translatedText, '[ru] hello');
      expect(result.source, TranslationSource.platform);
      expect(result.usageExamples, isEmpty);
    });

    test('lookupPronunciation returns an empty list', () async {
      final result = await service.lookupPronunciation(
        word: 'hello',
        lang: 'en',
      );
      expect(result, isEmpty);
    });
  });

  group('BundledTranslationService', () {
    late Uint8List translationFixtureBytes;
    late Directory docsDir;

    setUpAll(() async {
      translationFixtureBytes = await _buildTranslationFixture();
    });

    setUp(() async {
      docsDir = await Directory.systemTemp.createTemp('phonetic_docs_');
    });

    tearDown(() async {
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    });

    BundledTranslationService buildSubject({
      OnDeviceTranslationClient? onDeviceTranslationClient,
      RemoteTranslationClient? remoteTranslationClient,
      bool preferRemoteTranslation = false,
      bool enableDevelopmentEchoFallback = true,
    }) => BundledTranslationService(
      directoryProvider: () async => docsDir,
      assetLoader: (key) async {
        if (key.contains('/translation/')) {
          return ByteData.sublistView(translationFixtureBytes);
        }
        throw StateError('Unexpected asset load: $key');
      },
      databaseOpener: (path) => databaseFactoryFfi.openDatabase(path),
      onDeviceTranslationClient: onDeviceTranslationClient,
      remoteTranslationClient: remoteTranslationClient,
      preferRemoteTranslation: preferRemoteTranslation,
      enableDevelopmentEchoFallback: enableDevelopmentEchoFallback,
    );

    group('translate', () {
      test('returns an exact bundled translation when installed', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final result = await service.translate(
          'Hello',
          fromLang: 'en',
          toLang: 'ru',
        );
        expect(result.originalText, 'Hello');
        expect(result.translatedText, 'привет, здравствуй');
        expect(result.source, TranslationSource.platform);
        expect(result.context, 'greeting');
        expect(result.usageExamples, ['Hello there.']);
      });

      test(
        'returns an exact bundled reverse translation when installed',
        () async {
          final service = buildSubject();
          addTearDown(service.dispose);

          final result = await service.translate(
            'Привет',
            fromLang: 'ru',
            toLang: 'en',
          );
          expect(result.originalText, 'Привет');
          expect(result.translatedText, 'hi, hello');
          expect(result.source, TranslationSource.platform);
        },
      );

      test('returns the stub echo when the pair or text is missing', () async {
        final service = buildSubject();
        addTearDown(service.dispose);

        final missingText = await service.translate(
          'missing',
          fromLang: 'en',
          toLang: 'ru',
        );
        expect(missingText.translatedText, '[ru] missing');

        final missingPair = await service.translate(
          'hello',
          fromLang: 'en',
          toLang: 'it',
        );
        expect(missingPair.translatedText, '[it] hello');
      });

      test('uses on-device translation for bundled misses', () async {
        final onDevice = _FakeOnDeviceTranslationClient(result: 'локально');
        final service = buildSubject(onDeviceTranslationClient: onDevice);
        addTearDown(service.dispose);

        final result = await service.translate(
          'missing',
          fromLang: 'en',
          toLang: 'ru',
          contextText: 'Missing appears in this sentence.',
        );

        expect(result.translatedText, 'локально');
        expect(result.source, TranslationSource.platform);
        expect(onDevice.calls, 1);
        expect(onDevice.lastContextText, 'Missing appears in this sentence.');
      });

      test('prefers remote translation when configured', () async {
        final remote = _FakeRemoteTranslationClient(
          result: const TranslationResult(
            originalText: 'missing',
            translatedText: 'удаленно',
            source: TranslationSource.remote,
            context: 'remote context',
            usageExamples: ['Example'],
          ),
        );
        final onDevice = _FakeOnDeviceTranslationClient(result: 'локально');
        final service = buildSubject(
          remoteTranslationClient: remote,
          onDeviceTranslationClient: onDevice,
          preferRemoteTranslation: true,
        );
        addTearDown(service.dispose);

        final result = await service.translate(
          'missing',
          fromLang: 'en',
          toLang: 'ru',
          contextText: 'Missing appears in this sentence.',
        );

        expect(result.translatedText, 'удаленно');
        expect(result.source, TranslationSource.remote);
        expect(result.context, 'remote context');
        expect(result.usageExamples, ['Example']);
        expect(remote.calls, 1);
        expect(remote.lastContextText, 'Missing appears in this sentence.');
        expect(onDevice.calls, 0);
      });

      test('falls back to on-device translation when remote misses', () async {
        final remote = _FakeRemoteTranslationClient();
        final onDevice = _FakeOnDeviceTranslationClient(result: 'локально');
        final service = buildSubject(
          remoteTranslationClient: remote,
          onDeviceTranslationClient: onDevice,
          preferRemoteTranslation: true,
        );
        addTearDown(service.dispose);

        final result = await service.translate(
          'missing',
          fromLang: 'en',
          toLang: 'ru',
        );

        expect(result.translatedText, 'локально');
        expect(remote.calls, 1);
        expect(onDevice.calls, 1);
      });

      test(
        'throws when every source misses and echo fallback is disabled',
        () async {
          final service = buildSubject(enableDevelopmentEchoFallback: false);
          addTearDown(service.dispose);

          await expectLater(
            service.translate('missing', fromLang: 'en', toLang: 'ru'),
            throwsA(isA<TranslationException>()),
          );
        },
      );
    });

    group('lookupPronunciation', () {
      test(
        'returns empty because no phonetic db ships in the bundle',
        () async {
          final service = buildSubject();
          addTearDown(service.dispose);

          final results = await service.lookupPronunciation(
            word: 'hello',
            lang: 'en',
          );

          expect(results, isEmpty);
        },
      );

      test('does not load phonetic assets', () async {
        var assetLoads = 0;
        final service = BundledTranslationService(
          directoryProvider: () async => docsDir,
          assetLoader: (key) async {
            assetLoads += 1;
            throw StateError('Unexpected asset load: $key');
          },
          databaseOpener: (path) => databaseFactoryFfi.openDatabase(path),
        );
        addTearDown(service.dispose);

        await service.lookupPronunciation(word: 'hello', lang: 'en');

        expect(assetLoads, 0);
      });
    });
  });
}
