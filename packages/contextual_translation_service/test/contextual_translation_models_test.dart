import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ContextualTranslationRequest serializes stable wire keys', () {
    final request = ContextualTranslationRequest(
      requestId: 'request-1',
      sourceLanguage: autoSourceLanguageCode,
      sourceLanguageHint: 'en-US',
      targetLanguage: 'ru',
      selection: const TranslationSelection(
        text: 'up',
        normalizedText: 'up',
        kind: 'exact',
      ),
      context: const TranslationTextContext(
        level: 'sentence',
        current: TranslationContextPassage(
          text: 'He finally gave up smoking.',
          markedText: 'He finally gave [[up]] smoking.',
        ),
      ),
      anchor: const TranslationAnchor(
        sourceId: 'book-1',
        sourceType: 'book',
        cfiRange: 'epubcfi(/6/8)',
        progress: 0.25,
      ),
    );

    final json = request.toJson();

    expect(json['schema_version'], contextualTranslationRequestSchemaVersion);
    expect(json['source_language'], autoSourceLanguageCode);
    expect(json['source_language_hint'], 'en-US');
    expect(request.concreteSourceLanguage, 'en');
    expect((json['selection'] as Map)['normalized_text'], 'up');
    expect((json['anchor'] as Map)['source_type'], 'book');
  });

  test('TranslationAnchor drops oversized chapter title from wire payload', () {
    final oversizedTitle = List.filled(
      contextualTranslationAnchorChapterTitleMaxLength + 1,
      'x',
    ).join();
    final anchor = TranslationAnchor(
      sourceId: 'book-1',
      sourceType: 'book',
      chapterTitle: oversizedTitle,
    );

    expect(anchor.toJson()['chapter_title'], isNull);
  });

  test('TranslationAnchor normalizes a valid chapter title', () {
    const anchor = TranslationAnchor(
      sourceId: 'book-1',
      sourceType: 'book',
      chapterTitle: '  Chapter\n  One  ',
    );

    expect(anchor.toJson()['chapter_title'], 'Chapter One');
  });

  test('offline result preserves selected text translation mode', () {
    final request = ContextualTranslationRequest(
      requestId: 'request-1',
      sourceLanguage: 'en',
      targetLanguage: 'ru',
      mode: selectedTextTranslationMode,
      selection: const TranslationSelection(text: 'Release continuously.'),
      context: const TranslationTextContext(level: 'selection'),
      anchor: const TranslationAnchor(
        sourceId: 'article-1',
        sourceType: 'article',
      ),
    );

    final result = ContextualTranslationResult.offline(
      request: request,
      sourceLanguage: 'en',
      selectedTranslation: 'Выпускайте непрерывно.',
    );

    expect(result.mode, selectedTextTranslationMode);
  });

  test('ContextualTranslationResult parses backend response', () {
    final result = ContextualTranslationResult.fromJson({
      'schema_version': contextualTranslationResultSchemaVersion,
      'request_id': 'request-1',
      'mode': contextualTranslationMode,
      'status': 'resolved',
      'reliability': 'verified',
      'detected_source_language': 'en',
      'target_language': 'ru',
      'analysis': {
        'surface_form': 'gave up',
        'lemma': 'give up',
        'selected_token_ids': [3],
        'expression_token_ids': [2, 3],
      },
      'translation': {
        'contextual_translation': 'бросил',
        'sentence_translation': 'Он наконец бросил курить.',
      },
      'alternatives': [
        {'translation': 'отказался'},
      ],
      'source': {
        'provider': 'deepseek',
        'schema_version': contextualTranslationResultSchemaVersion,
      },
    });

    expect(result.status, ContextualTranslationStatus.resolved);
    expect(result.reliability, ContextualTranslationReliability.verified);
    expect(result.analysis?.lemma, 'give up');
    expect(result.translation.contextualTranslation, 'бросил');
    expect(result.alternatives.single.translation, 'отказался');
  });

  test('ContextualTranslationResult rejects an unknown schema', () {
    expect(
      () => ContextualTranslationResult.fromJson({
        ..._validResultJson,
        'schema_version': 'readflex.contextual_translation.result.v2',
      }),
      throwsFormatException,
    );
  });

  test(
    'contextual expression is distinct from the selected word translation',
    () {
      final result = ContextualTranslationResult.fromJson({
        ..._validResultJson,
        'analysis': {'surface_form': 'into'},
        'translation': {'contextual_translation': 'в'},
        'contextual_expression': {
          'text': 'falls into',
          'translation': 'относится к',
        },
      });
      expect(result.toJson()['contextual_expression'], {
        'text': 'falls into',
        'translation': 'относится к',
      });
      expect(result.translation.contextualTranslation, 'в');
      expect(ContextualTranslationResult.fromJson(result.toJson()), result);
      expect(
        ContextualTranslationResult.fromJson({
          ...result.toJson(),
          'contextual_expression': null,
        }),
        isNot(result),
      );
    },
  );

  test('legacy and text translation responses need no expression', () {
    expect(
      ContextualTranslationResult.fromJson(
        _validResultJson,
      ).contextualExpression,
      isNull,
    );
    final text = ContextualTranslationResult.fromJson({
      ..._validResultJson,
      'mode': selectedTextTranslationMode,
      'contextual_expression': {'unrelated': 'ignored'},
    });
    expect(text.contextualExpression, isNull);
  });

  for (final entry in <String, Object>{
    'not an object': 'invalid',
    'missing translation': {'text': 'falls into'},
    'blank source': {'text': '  ', 'translation': 'относится к'},
    'non-string translation': {'text': 'falls into', 'translation': 42},
    'oversized source': {'text': 'x' * 513, 'translation': 'valid'},
    'oversized translation': {
      'text': 'valid source',
      'translation': 'x' * 2049,
    },
  }.entries) {
    test('rejects malformed expression: ${entry.key}', () {
      expect(
        () => ContextualTranslationResult.fromJson({
          ..._validResultJson,
          'contextual_expression': entry.value,
        }),
        throwsFormatException,
      );
    });
  }

  test('optional pronunciation metadata survives JSON and equality', () {
    final analysis = ContextualTranslationAnalysis.fromJson({
      'surface_form': 'reading',
      'lemma': 'read',
      'pronunciation': '/\u02c8ri\u02d0d\u026a\u014b/',
      'reading': null,
    });
    expect(analysis.toJson()['pronunciation'], '/\u02c8ri\u02d0d\u026a\u014b/');
    expect(ContextualTranslationAnalysis.fromJson(analysis.toJson()), analysis);
    expect(
      ContextualTranslationAnalysis.fromJson({
        ...analysis.toJson(),
        'pronunciation': null,
      }),
      isNot(analysis),
    );
    final reading = ContextualTranslationAnalysis.fromJson({
      'surface_form': '銀行',
      'reading': 'ぎんこう',
    });
    expect(reading.toJson()['reading'], 'ぎんこう');
    expect(ContextualTranslationAnalysis.fromJson(reading.toJson()), reading);
  });

  test('old responses do not require pronunciation metadata', () {
    final result = ContextualTranslationResult.fromJson({
      ..._validResultJson,
      'analysis': {'lemma': 'power'},
    });
    expect(result.analysis!.toJson()['pronunciation'], isNull);
    expect(result.analysis!.toJson()['reading'], isNull);
    expect(result.translation.contextualTranslation, 'сила');
  });

  test('ContextualTranslationResult rejects unknown enum values', () {
    expect(
      () => ContextualTranslationResult.fromJson({
        ..._validResultJson,
        'status': 'complete',
      }),
      throwsFormatException,
    );
    expect(
      () => ContextualTranslationResult.fromJson({
        ..._validResultJson,
        'reliability': 'certain',
      }),
      throwsFormatException,
    );
  });

  test('resolved result requires non-empty translated text', () {
    expect(
      () => ContextualTranslationResult.fromJson({
        ..._validResultJson,
        'translation': <String, Object?>{},
      }),
      throwsFormatException,
    );
  });
}

final _validResultJson = <String, Object?>{
  'schema_version': contextualTranslationResultSchemaVersion,
  'request_id': 'request-1',
  'mode': contextualTranslationMode,
  'status': 'resolved',
  'reliability': 'verified',
  'translation': <String, Object?>{'contextual_translation': 'сила'},
  'source': <String, Object?>{
    'provider': 'deepseek',
    'schema_version': contextualTranslationResultSchemaVersion,
  },
};
