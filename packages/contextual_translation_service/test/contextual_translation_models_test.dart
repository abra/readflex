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
