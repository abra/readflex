import 'dart:convert';

import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:reader_webview/src/reader_common_handlers.dart';
import 'package:shared/shared.dart';
import 'package:translate/src/translate_cubit.dart';
import 'package:translation_service/translation_service.dart';

void main() {
  group('reader selection -> translate flow', () {
    test(
      'handles contextual translation variants from an EPUB selection',
      () async {
        final translationService = _FixtureTranslationService({
          'stakeholders': jsonEncode({
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
            ],
          }),
          'kick': jsonEncode({
            'mode': 'word_in_expression',
            'word': 'kick',
            'word_translation': 'пинать',
            'definition': {
              'source': 'To begin something in this expression.',
              'target': 'Начать что-либо в этом выражении.',
            },
            'phrase': {
              'text': 'kick things off',
              'type': 'phrasal_verb',
            },
            'marked_sentence': 'It is time to [[kick things off]].',
            'usage_examples': ['They [[kicked the project off]] together.'],
          }),
          'circumvent': jsonEncode({
            'mode': 'single_word',
            'word': 'circumvent',
            'word_translation': 'обойти',
            'part_of_speech': 'verb',
            'transcription': '/ˌsɜːrkəmˈvent/',
            'definition': {
              'source':
                  'To avoid a restriction or problem by finding a way around it.',
              'target': 'Обойти ограничение или проблему.',
            },
            'marked_sentence': 'The team will [[circumvent]] the restriction.',
          }),
          'out of service': jsonEncode({
            'mode': 'selected_expression',
            'text': 'out of service',
            'translation': 'не работает',
            'phrase_type': 'fixed_phrase',
            'definition': {
              'source': 'Not available for use or operation.',
              'target': 'Недоступен для использования или работы.',
            },
            'marked_sentence': 'The elevator is [[out of service]].',
            'usage_examples': ['The printer is [[out of service]].'],
          }),
        });
        final dictionaryRepository = _FakeDictionaryRepository();
        final cubit = TranslateCubit(
          translationService: translationService,
          dictionaryRepository: dictionaryRepository,
          fsrsRepository: _FakeFsrsRepository(),
        );
        addTearDown(cubit.close);

        final pluralSelection = _selectionFromEpubPayload({
          'text': 'stakeholders',
          'cfi': 'epubcfi(/6/4!/4,/18,/20)',
          'contextText':
              'Leadership and stakeholders joined before the decision was made.',
          'markedContextText':
              'Leadership and [[stakeholders]] joined before the decision was made.',
        });

        await cubit.translate(
          text: pluralSelection.textForTranslation,
          fromLang: 'en',
          toLang: 'ru',
          contextText: pluralSelection.contextText,
          markedContextText: pluralSelection.markedContextTextForTranslation,
        );

        expect(translationService.lastText, 'stakeholders');
        expect(
          translationService.lastContextText,
          'Leadership and [[stakeholders]] joined before the decision was made.',
        );
        expect(cubit.state.translatedText, 'заинтересованные стороны');
        expect(cubit.state.sense!.lemma, 'stakeholder');
        expect(cubit.state.sense!.lemmaTranscription, '/ˈsteɪkˌhoʊldər/');
        expect(cubit.state.naturalEquivalents, ['shareholder — акционер']);

        await cubit.saveToDictionary(
          word: pluralSelection.textForTranslation,
          sourceId: pluralSelection.sourceId,
          sourceType: pluralSelection.sourceType,
        );
        expect(dictionaryRepository.entries.single.word, 'stakeholders');
        expect(
          dictionaryRepository.entries.single.pronunciation,
          '/ˈsteɪkˌhoʊldər/',
        );
        expect(
          dictionaryRepository.entries.single.context,
          'Leadership and stakeholders joined before the decision was made.',
        );

        final partialSelection = _selectionFromEpubPayload({
          'text': 'cumven',
          'normalizedText': 'circumvent',
          'selectionKind': 'partial_word',
          'cfi': 'epubcfi(/6/6!/4,/10,/12)',
          'contextText': 'The team will circumvent the restriction.',
          'markedContextText': 'The team will cir[[cumven]]t the restriction.',
          'normalizedMarkedContextText':
              'The team will [[circumvent]] the restriction.',
        });

        await cubit.translate(
          text: partialSelection.textForTranslation,
          fromLang: 'en',
          toLang: 'ru',
          contextText: partialSelection.contextText,
          markedContextText: partialSelection.markedContextTextForTranslation,
        );

        expect(partialSelection.selectedText, 'cumven');
        expect(partialSelection.normalizedSelectedText, 'circumvent');
        expect(translationService.lastText, 'circumvent');
        expect(
          translationService.lastContextText,
          'The team will [[circumvent]] the restriction.',
        );
        expect(cubit.state.translatedText, 'обойти');

        await cubit.saveToDictionary(
          word: partialSelection.textForTranslation,
          sourceId: partialSelection.sourceId,
          sourceType: partialSelection.sourceType,
        );
        expect(dictionaryRepository.entries.last.word, 'circumvent');

        final expressionSelection = _selectionFromEpubPayload({
          'text': 'kick',
          'cfi': 'epubcfi(/6/8!/4,/2,/10)',
          'contextText': 'It is time to kick things off.',
          'markedContextText': 'It is time to [[kick]] things off.',
        });
        await cubit.translate(
          text: expressionSelection.textForTranslation,
          fromLang: 'en',
          toLang: 'ru',
          contextText: expressionSelection.contextText,
          markedContextText:
              expressionSelection.markedContextTextForTranslation,
        );

        expect(
          cubit.state.answerType,
          TranslationAnswerType.expressionExplanation,
        );
        expect(cubit.state.translatedText, 'пинать');
        expect(cubit.state.expression!.surface, 'kick things off');
        expect(cubit.state.usageExamples, [
          'It is time to [[kick things off]].',
          'They [[kicked the project off]] together.',
        ]);

        final spanSelection = _selectionFromEpubPayload({
          'text': 'out of service',
          'cfi': 'epubcfi(/6/12!/4,/14,/18)',
          'contextText': 'The elevator is out of service.',
          'markedContextText': 'The elevator is [[out of service]].',
        });
        await cubit.translate(
          text: spanSelection.textForTranslation,
          fromLang: 'en',
          toLang: 'ru',
          contextText: spanSelection.contextText,
          markedContextText: spanSelection.markedContextTextForTranslation,
        );

        expect(
          cubit.state.answerType,
          TranslationAnswerType.expressionExplanation,
        );
        expect(cubit.state.translatedText, 'не работает');
        expect(cubit.state.expression!.surface, 'out of service');
        expect(
          cubit.state.sense!.sourceDefinition,
          'Not available for use or operation.',
        );
      },
    );
  });
}

TextSelectionContext _selectionFromEpubPayload(Map<String, Object?> payload) {
  final selection = parseReaderSelectionPayload(payload)!;
  return TextSelectionContext(
    selectedText: selection.text,
    normalizedSelectedText: selection.normalizedText,
    selectionKind: selection.selectionKind,
    sourceId: 'epub-book-1',
    sourceType: SourceType.book,
    contextText: selection.contextText,
    markedContextText: selection.markedContextText,
    normalizedMarkedContextText: selection.normalizedMarkedContextText,
    cfiRange: selection.cfiRange,
    scrollOffset: selection.scrollOffset,
  );
}

class _FixtureTranslationService implements TranslationService {
  _FixtureTranslationService(this.responses);

  final Map<String, String> responses;
  String? lastText;
  String? lastContextText;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    lastText = text;
    lastContextText = contextText;
    final response = responses[text];
    if (response == null) throw const TranslationException('Missing fixture');
    final result = DeepSeekDirectTranslationClient.decodeModelPayloadForTesting(
      response,
      originalText: text,
      sourceLanguage: fromLang,
      targetLanguage: toLang,
    );
    if (result == null) throw const TranslationException('Invalid fixture');
    return result;
  }

  @override
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  }) async => const [];

  @override
  Future<void> dispose() async {}
}

class _FakeDictionaryRepository implements DictionaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final entries = <DictionaryEntry>[];

  @override
  Future<DictionaryEntry> addEntry({
    required String word,
    required String translation,
    String? pronunciation,
    String? partOfSpeech,
    String? context,
    String? sourceId,
    SourceType? sourceType,
    List<String> usageExamples = const [],
    DateTime? addedAt,
    String? anchorText,
    String? anchorContext,
    String? anchorCfiRange,
    DictionaryAnchorKind? anchorKind,
  }) async {
    final entry = DictionaryEntry(
      id: 'entry-${entries.length + 1}',
      word: word,
      translation: translation,
      pronunciation: pronunciation,
      partOfSpeech: partOfSpeech,
      context: context,
      sourceId: sourceId,
      sourceType: sourceType,
      usageExamples: usageExamples,
      addedAt: addedAt ?? DateTime(2026),
    );
    entries.add(entry);
    return entry;
  }
}

class _FakeFsrsRepository implements FsrsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> createReviewItem({
    required String itemId,
    required ReviewableType itemType,
    String? sourceId,
  }) async {}
}
