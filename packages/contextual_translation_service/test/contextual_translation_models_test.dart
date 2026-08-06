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

  test('ContextualTranslationResult parses backend response', () {
    final result = ContextualTranslationResult.fromJson({
      'request_id': 'request-1',
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
    });

    expect(result.status, ContextualTranslationStatus.resolved);
    expect(result.reliability, ContextualTranslationReliability.verified);
    expect(result.analysis?.lemma, 'give up');
    expect(result.translation.contextualTranslation, 'бросил');
    expect(result.alternatives.single.translation, 'отказался');
  });
}
