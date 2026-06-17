import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'remote_translation_client.dart';
import 'translation_service.dart';

/// Direct DeepSeek translation client.
///
/// This is intentionally a replaceable adapter, not app business logic. It is
/// acceptable for local development or internal builds, but a shipped app must
/// route this through a Readflex backend because client binaries cannot protect
/// API keys or enforce server-side privacy/rate-limit rules.
class DeepSeekDirectTranslationClient implements RemoteTranslationClient {
  DeepSeekDirectTranslationClient({
    required String apiKey,
    Uri? baseUri,
    String model = _defaultModel,
    Duration timeout = const Duration(seconds: 15),
    HttpClient? httpClient,
  }) : _apiKey = apiKey.trim(),
       _baseUri = baseUri ?? Uri.parse('https://api.deepseek.com'),
       _model = model.trim().isEmpty ? _defaultModel : model.trim(),
       _timeout = timeout,
       _httpClient = httpClient ?? HttpClient(),
       _ownsHttpClient = httpClient == null;

  static const _defaultModel = 'deepseek-v4-pro';
  static const _maxOutputTokens = 2000;

  final String _apiKey;
  final Uri _baseUri;
  final String _model;
  final Duration _timeout;
  final HttpClient _httpClient;
  final bool _ownsHttpClient;

  @override
  Future<TranslationResult?> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async {
    final normalizedText = text.trim();
    final normalizedContextText = contextText?.trim();
    if (_apiKey.isEmpty || normalizedText.isEmpty) return null;

    final userPayload = _buildUserPayload(
      rawText: text,
      normalizedText: normalizedText,
      fromLang: fromLang,
      toLang: toLang,
      normalizedContextText: normalizedContextText,
    );

    final payload = _buildRequestPayload(
      model: _model,
      userPayload: userPayload,
    );

    try {
      final request = await _httpClient
          .postUrl(_chatCompletionsUri())
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(_timeout);
      final body = await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final content = _extractMessageContent(body);
      if (content == null) return null;

      final result = _decodeModelPayload(
        content,
        originalText: normalizedText,
        sourceLanguage: fromLang,
        targetLanguage: toLang,
      );
      final translatedText = result.translatedText;
      if (translatedText == null || translatedText.trim().isEmpty) {
        return null;
      }

      return result.toTranslationResult(
        originalText: normalizedText,
        translatedText: translatedText.trim(),
      );
    } on TimeoutException {
      return null;
    } on IOException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?> payloadForTesting({
    required String text,
    required String fromLang,
    required String toLang,
    String? contextText,
  }) => _buildUserPayload(
    rawText: text,
    normalizedText: text.trim(),
    fromLang: fromLang,
    toLang: toLang,
    normalizedContextText: contextText?.trim(),
  );

  static Map<String, Object?> requestPayloadForTesting({
    required Map<String, Object?> userPayload,
    String model = _defaultModel,
  }) => _buildRequestPayload(model: model, userPayload: userPayload);

  static Map<String, Object?> _buildRequestPayload({
    required String model,
    required Map<String, Object?> userPayload,
  }) {
    final payload = <String, Object?>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': jsonEncode(userPayload)},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0,
      'max_tokens': _maxOutputTokens,
    };
    if (_shouldDisableThinking(model)) {
      payload['thinking'] = {'type': 'disabled'};
    }
    return payload;
  }

  static bool _shouldDisableThinking(String model) {
    return model.trim().toLowerCase() == _defaultModel;
  }

  static Map<String, Object?> _buildUserPayload({
    required String rawText,
    required String normalizedText,
    required String fromLang,
    required String toLang,
    String? normalizedContextText,
  }) {
    final hasContext =
        normalizedContextText != null && normalizedContextText.isNotEmpty;
    final rawMarkedContextText = hasContext
        ? _buildMarkedContext(
            selectedText: normalizedText,
            contextText: normalizedContextText,
          )
        : null;
    final contextWindow = rawMarkedContextText == null
        ? null
        : _markedContextWindow(rawMarkedContextText);
    final markedContextText = contextWindow?.markedText;
    final plainContextText = markedContextText == null
        ? null
        : _stripSelectionMarkers(markedContextText);
    return <String, Object?>{
      'source_language': fromLang,
      'source_language_name': _languageName(fromLang),
      'target_language': toLang,
      'target_language_name': _languageName(toLang),
      'raw_selected_text': rawText,
      'selected_text': normalizedText,
      'text': normalizedText,
      if (hasContext) 'context_text': plainContextText,
      if (hasContext) 'marked_context': markedContextText,
      if (hasContext && contextWindow != null)
        'context': contextWindow.toPlainJson(),
    };
  }

  static String _languageName(String code) {
    final normalized = code.trim().toLowerCase();
    return switch (normalized) {
      'ar' => 'Arabic',
      'de' => 'German',
      'en' => 'English',
      'es' => 'Spanish',
      'fr' => 'French',
      'hi' => 'Hindi',
      'it' => 'Italian',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'pt' => 'Portuguese',
      'ru' => 'Russian',
      'zh' => 'Chinese',
      _ => normalized.isEmpty ? code : normalized,
    };
  }

  @override
  Future<void> dispose() async {
    if (_ownsHttpClient) {
      _httpClient.close(force: true);
    }
  }

  Uri _chatCompletionsUri() {
    final base = _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base/chat/completions');
  }

  static String? _extractMessageContent(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, Object?>) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final firstChoice = choices.first;
    if (firstChoice is! Map<String, Object?>) return null;
    final message = firstChoice['message'];
    if (message is! Map<String, Object?>) return null;
    final content = message['content'];
    return content is String ? content.trim() : null;
  }

  static _DecodedPayload _decodeModelPayload(
    String content, {
    required String originalText,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final jsonObject = _extractJsonObject(content);
    final decoded = jsonDecode(jsonObject);
    if (decoded is! Map<String, Object?>) return const _DecodedPayload();

    final modelTranslatedText =
        _nonEmptyString(decoded['translated_text']) ??
        _nonEmptyString(decoded['word_translation']) ??
        _targetString(decoded['translation']) ??
        _nonEmptyString(decoded['translation']);
    final rawContext = decoded['context'];
    final decodedAnswerType = _answerTypeWithModeFallback(
      _answerTypeFromString(decoded['answer_type']),
      decoded['mode'],
    );
    final confidence = _confidenceFromString(decoded['confidence']);
    final wordForm = _wordFormFromDecoded(decoded);
    final rawSense =
        _senseFromMap(decoded['sense']) ??
        _senseFromDefinitionAndContext(
          decoded['definition'],
          decoded['context_explanation'],
          partOfSpeech: decoded['part_of_speech'],
          transcription: decoded['transcription'],
          lemma: decoded['lemma'] ?? wordForm?['lemma'],
          lemmaTranscription:
              decoded['lemma_transcription'] ?? wordForm?['transcription'],
          grammaticalForm: decoded['grammatical_form'] ?? wordForm?['form'],
        );
    final expression = _normalizeExpressionClassification(
      _expressionFromMap(decoded['expression'], fallbackTerm: originalText) ??
          _expressionFromMinimalPayload(decoded, fallbackTerm: originalText) ??
          _expressionFromRoot(decoded, fallbackTerm: originalText) ??
          _expressionFromSenseFallback(rawSense, fallbackTerm: originalText),
      selectedText: originalText,
    );
    final answerType = _answerTypeWithExpressionFallback(
      decodedAnswerType,
      expression,
    );
    final sanitizedSense = _sanitizeSense(
      rawSense,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    final sense = _repairSenseForExpressionClassification(
      _restoreSourceSenseFallback(
        sanitizedSense,
        rawSense: rawSense,
        expression: expression,
        originalText: originalText,
        answerType: answerType,
        sourceLanguage: sourceLanguage,
      ),
      expression: expression,
    );
    final notes = _pairFromMap(decoded['notes']);
    final allowSuggestedPhraseFallback =
        _nonEmptyString(decoded['mode']) != 'word_in_expression';
    final suggestedFullPhrase =
        _suggestedFullPhraseFromMinimalPayload(decoded) ??
        _suggestedFullPhrase(decoded, expression) ??
        (allowSuggestedPhraseFallback
            ? _suggestedFullPhraseFromSenseFallback(
                sense,
                expression,
                originalText: originalText,
              )
            : null);
    final literalTranslation = _targetString(decoded['literal_translation']);
    final translatedText = _selectedTextTranslation(
      modelTranslatedText: modelTranslatedText,
      literalTranslation: literalTranslation,
      originalText: originalText,
      answerType: answerType,
      expression: expression,
    );
    final context = sense == null
        ? _contextFromExpression(
                decoded['expression'],
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
              ) ??
              (rawContext is String && rawContext.trim().isNotEmpty
                  ? rawContext.trim()
                  : null)
        : null;

    return _DecodedPayload(
      translatedText: translatedText,
      answerType: answerType,
      confidence: confidence,
      sense: sense,
      expression: expression,
      context: context,
      usageExamples: _usageExamples(decoded, expression: expression),
      naturalEquivalents: _naturalEquivalentsFromDecoded(
        decoded,
        originalText: originalText,
        expression: expression,
      ),
      literalTranslation: literalTranslation,
      suggestedFullPhrase: suggestedFullPhrase,
      notes: notes,
    );
  }

  static TranslationSense? _senseFromMap(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final wordForm = _wordFormFromDecoded(value);
    final sense = TranslationSense(
      partOfSpeech: _nonEmptyString(value['part_of_speech']),
      transcription: _ipaString(value['transcription']),
      lemma: _nonEmptyString(value['lemma'] ?? wordForm?['lemma']),
      lemmaTranscription: _ipaString(
        value['lemma_transcription'] ?? wordForm?['transcription'],
      ),
      grammaticalForm: _nonEmptyString(
        value['grammatical_form'] ?? wordForm?['form'],
      ),
      sourceDefinition: _nonEmptyString(value['source_definition']),
      targetDefinition: _nonEmptyString(value['target_definition']),
      sourceContextNote: _nonEmptyString(value['source_context_note']),
      targetContextNote: _nonEmptyString(value['target_context_note']),
    );
    return sense.isEmpty ? null : sense;
  }

  static TranslationSense? _senseFromDefinitionAndContext(
    Object? definition,
    Object? contextExplanation, {
    Object? partOfSpeech,
    Object? transcription,
    Object? lemma,
    Object? lemmaTranscription,
    Object? grammaticalForm,
  }) {
    final sense = TranslationSense(
      partOfSpeech: _nonEmptyString(partOfSpeech),
      transcription: _ipaString(transcription),
      lemma: _nonEmptyString(lemma),
      lemmaTranscription: _ipaString(lemmaTranscription),
      grammaticalForm: _nonEmptyString(grammaticalForm),
      sourceDefinition: _sourceString(definition),
      targetDefinition: _targetString(definition),
      sourceContextNote: _sourceString(contextExplanation),
      targetContextNote: _targetString(contextExplanation),
    );
    return sense.isEmpty ? null : sense;
  }

  static Map<String, Object?>? _wordFormFromDecoded(
    Map<String, Object?> decoded,
  ) {
    final wordForm = decoded['word_form'];
    if (wordForm is! Map<String, Object?>) return null;

    final form = _nonEmptyString(wordForm['form'])?.toLowerCase();
    final lemma = _nonEmptyString(wordForm['lemma']);
    if (form == null || lemma == null) return null;

    final allowed = {
      'plural',
      'gerund',
      'present_participle',
      'past',
      'past_tense',
      'comparative',
      'superlative',
    };
    if (!allowed.contains(form)) return null;
    if (form == 'plural' &&
        !_looksLikeEnglishPluralLemma(
          selected:
              _nonEmptyString(decoded['word']) ??
              _nonEmptyString(decoded['selected_text']) ??
              _nonEmptyString(decoded['text']),
          lemma: lemma,
        )) {
      return null;
    }
    return wordForm;
  }

  static bool _looksLikeEnglishPluralLemma({
    required String? selected,
    required String lemma,
  }) {
    final normalizedSelected = selected?.trim().toLowerCase();
    final normalizedLemma = lemma.trim().toLowerCase();
    if (normalizedSelected == null ||
        normalizedSelected.isEmpty ||
        normalizedLemma.isEmpty) {
      return false;
    }
    return normalizedSelected == '${normalizedLemma}s' ||
        normalizedSelected == '${normalizedLemma}es' ||
        (normalizedLemma.endsWith('y') &&
            normalizedSelected ==
                '${normalizedLemma.substring(0, normalizedLemma.length - 1)}ies');
  }

  static TranslationSense? _sanitizeSense(
    TranslationSense? sense, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    if (sense == null) return null;
    final sanitized = TranslationSense(
      partOfSpeech: sense.partOfSpeech,
      transcription: sense.transcription,
      lemma: sense.lemma,
      lemmaTranscription: sense.lemmaTranscription,
      grammaticalForm: sense.grammaticalForm,
      sourceDefinition:
          _matchesExpectedLanguage(
            sense.sourceDefinition,
            sourceLanguage,
            targetLanguage,
          )
          ? sense.sourceDefinition
          : null,
      targetDefinition:
          _matchesExpectedLanguage(
            sense.targetDefinition,
            targetLanguage,
            sourceLanguage,
          )
          ? sense.targetDefinition
          : null,
      sourceContextNote:
          _matchesExpectedLanguage(
            sense.sourceContextNote,
            sourceLanguage,
            targetLanguage,
          )
          ? sense.sourceContextNote
          : null,
      targetContextNote:
          _matchesExpectedLanguage(
            sense.targetContextNote,
            targetLanguage,
            sourceLanguage,
          )
          ? sense.targetContextNote
          : null,
    );
    return sanitized.isEmpty ? null : sanitized;
  }

  static bool _matchesExpectedLanguage(
    String? value,
    String expectedLanguage,
    String otherLanguage,
  ) {
    if (value == null || value.trim().isEmpty) return false;
    if (!_canDetectLanguageConflict(expectedLanguage, otherLanguage)) {
      return true;
    }
    final expected = expectedLanguage.trim().toLowerCase();
    final other = otherLanguage.trim().toLowerCase();
    if (expected == 'en' && other == 'ru') return !_containsCyrillic(value);
    if (expected == 'ru' && other == 'en') return _containsCyrillic(value);
    return true;
  }

  static bool _canDetectLanguageConflict(String first, String second) {
    final normalized = {
      first.trim().toLowerCase(),
      second.trim().toLowerCase(),
    };
    return normalized.contains('en') && normalized.contains('ru');
  }

  static bool _containsCyrillic(String value) =>
      RegExp(r'[\u0400-\u04FF]').hasMatch(value);

  static TranslationSense? _restoreSourceSenseFallback(
    TranslationSense? sanitizedSense, {
    required TranslationSense? rawSense,
    required TranslationExpression? expression,
    required String originalText,
    required TranslationAnswerType answerType,
    required String sourceLanguage,
  }) {
    if (sourceLanguage.trim().toLowerCase() != 'en' ||
        rawSense == null ||
        expression == null ||
        answerType != TranslationAnswerType.expressionExplanation) {
      return sanitizedSense;
    }

    final needsSourceDefinition =
        rawSense.sourceDefinition != null &&
        sanitizedSense?.sourceDefinition == null;
    final needsSourceContext =
        rawSense.sourceContextNote != null &&
        sanitizedSense?.sourceContextNote == null;
    if (!needsSourceDefinition && !needsSourceContext) return sanitizedSense;

    final restored = TranslationSense(
      partOfSpeech: sanitizedSense?.partOfSpeech ?? rawSense.partOfSpeech,
      transcription: sanitizedSense?.transcription ?? rawSense.transcription,
      lemma: sanitizedSense?.lemma ?? rawSense.lemma,
      lemmaTranscription:
          sanitizedSense?.lemmaTranscription ?? rawSense.lemmaTranscription,
      grammaticalForm:
          sanitizedSense?.grammaticalForm ?? rawSense.grammaticalForm,
      sourceDefinition:
          sanitizedSense?.sourceDefinition ??
          (needsSourceDefinition
              ? _sourceDefinitionFallback(originalText, expression)
              : null),
      targetDefinition: sanitizedSense?.targetDefinition,
      sourceContextNote:
          sanitizedSense?.sourceContextNote ??
          (needsSourceContext
              ? _sourceContextFallback(originalText, expression)
              : null),
      targetContextNote: sanitizedSense?.targetContextNote,
    );
    return restored.isEmpty ? null : restored;
  }

  static TranslationSense? _repairSenseForExpressionClassification(
    TranslationSense? sense, {
    required TranslationExpression? expression,
  }) {
    if (sense == null || expression == null) return sense;
    if (!_looksLikeNonPhrasalExpression(expression)) return sense;

    final expressionText = _expressionDisplayText(expression);
    if (expressionText == null) return sense;
    final repaired = TranslationSense(
      partOfSpeech: sense.partOfSpeech,
      transcription: sense.transcription,
      lemma: sense.lemma,
      lemmaTranscription: sense.lemmaTranscription,
      grammaticalForm: sense.grammaticalForm,
      sourceDefinition: _replaceWrongPhrasalClaim(
        sense.sourceDefinition,
        expressionText,
      ),
      targetDefinition: _replaceWrongPhrasalClaim(
        sense.targetDefinition,
        expressionText,
      ),
      sourceContextNote: _replaceWrongPhrasalClaim(
        sense.sourceContextNote,
        expressionText,
      ),
      targetContextNote: _replaceWrongPhrasalClaim(
        sense.targetContextNote,
        expressionText,
      ),
    );
    return repaired.isEmpty ? null : repaired;
  }

  static String? _expressionDisplayText(TranslationExpression expression) {
    for (final value in [
      expression.surface,
      expression.lexicalUnit,
      expression.normalizedExpression,
    ]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String? _replaceWrongPhrasalClaim(
    String? value,
    String expressionText,
  ) {
    if (value == null) return null;
    final normalized = value.toLowerCase();
    final claimsPhrasal =
        normalized.contains('phrasal') ||
        normalized.contains('particle used with a verb');
    final onlyPatternClaim =
        normalized.contains('particle') && normalized.contains('pattern');
    if (!claimsPhrasal && !onlyPatternClaim) return value;
    return 'The selected text is part of the larger expression "$expressionText" in this context.';
  }

  static String _sourceDefinitionFallback(
    String originalText,
    TranslationExpression expression,
  ) {
    final role = expression.selectedRole?.toLowerCase();
    if (role == 'particle') {
      return 'A particle used with a verb to form a phrasal-verb construction.';
    }
    if (role == 'object') {
      return 'An object placed inside a separable phrasal-verb construction.';
    }
    final head = _expressionHead(expression);
    if (head != null) {
      return 'The selected text "$originalText" functions as part of the expression "$head" in this context.';
    }
    return 'The selected text "$originalText" is used as part of a larger expression in this context.';
  }

  static String _sourceContextFallback(
    String originalText,
    TranslationExpression expression,
  ) {
    final surface = expression.surface;
    final head = _expressionHead(expression);
    final role = expression.selectedRole;
    final type = _humanizeForPrompt(
      expression.expressionType ?? expression.constructionType,
    );
    final pattern = expression.canonicalPattern;
    final parts = <String>[];
    if (surface != null) {
      parts.add(
        'The selected text "$originalText" appears${role == null ? '' : ' as the $role'} in "$surface"',
      );
    } else {
      parts.add(
        'The selected text "$originalText" is used${role == null ? '' : ' as the $role'} in this expression',
      );
    }
    if (head != null && head != surface) {
      parts.add('whose lexical unit is "$head"');
    }
    if (type.isNotEmpty) parts.add('a $type');
    if (pattern != null) parts.add('with the pattern "$pattern"');
    return '${parts.join(', ')}.';
  }

  static String? _expressionHead(TranslationExpression expression) =>
      expression.lexicalUnit ??
      expression.normalizedExpression ??
      expression.surface ??
      expression.term;

  static String _humanizeForPrompt(String? value) =>
      value?.trim().replaceAll('_', ' ') ?? '';

  static TranslationExpression? _expressionFromMap(
    Object? value, {
    required String fallbackTerm,
  }) {
    if (value is! Map<String, Object?>) return null;
    final expression = TranslationExpression(
      term:
          _nonEmptyString(value['term']) ??
          _nonEmptyString(value['selected_text']) ??
          fallbackTerm,
      normalizedExpression:
          _nonEmptyString(value['normalized_expression']) ??
          _nonEmptyString(value['lexical_unit']) ??
          _nonEmptyString(value['text']) ??
          _nonEmptyString(value['surface']),
      expressionType:
          _nonEmptyString(value['expression_type']) ??
          _nonEmptyString(value['type']) ??
          _nonEmptyString(value['construction_type']),
      selectedRole: _nonEmptyString(value['selected_role']),
      constructionType: _nonEmptyString(value['construction_type']),
      surface: _nonEmptyString(value['surface']),
      lexicalUnit: _nonEmptyString(value['lexical_unit']),
      canonicalPattern: _nonEmptyString(value['canonical_pattern']),
      isSelectedPartOfLexicalUnit: _bool(
        value['is_selected_part_of_lexical_unit'],
      ),
      isMultiwordExpression: _bool(value['is_multiword_expression']),
      partOfSpeech: _nonEmptyString(value['part_of_speech']),
      register: _nonEmptyString(value['register']),
      domain: _nonEmptyString(value['domain']),
    );
    return expression.isEmpty ? null : expression;
  }

  static TranslationExpression? _expressionFromMinimalPayload(
    Map<String, Object?> value, {
    required String fallbackTerm,
  }) {
    final mode = _nonEmptyString(value['mode']);
    final phrase = value['phrase'];
    if (phrase is Map<String, Object?>) {
      final phraseText =
          _nonEmptyString(phrase['text']) ??
          _nonEmptyString(phrase['source']) ??
          _nonEmptyString(phrase['surface']);
      if (phraseText == null) return null;
      final expression = TranslationExpression(
        term:
            _nonEmptyString(value['word']) ??
            _nonEmptyString(value['selected_text']) ??
            fallbackTerm,
        normalizedExpression: phraseText,
        expressionType:
            _nonEmptyString(phrase['type']) ??
            _nonEmptyString(value['phrase_type']),
        selectedRole: 'component',
        surface: phraseText,
        lexicalUnit: phraseText,
        isSelectedPartOfLexicalUnit: true,
        isMultiwordExpression: true,
      );
      return expression.isEmpty ? null : expression;
    }

    if (mode != 'selected_expression') return null;
    final selectedText =
        _nonEmptyString(value['text']) ??
        _nonEmptyString(value['selected_text']) ??
        fallbackTerm;
    final expression = TranslationExpression(
      term: selectedText,
      normalizedExpression: selectedText,
      expressionType: _nonEmptyString(value['phrase_type']),
      selectedRole: 'selection',
      surface: selectedText,
      lexicalUnit: selectedText,
      isSelectedPartOfLexicalUnit: true,
      isMultiwordExpression: true,
    );
    return expression.isEmpty ? null : expression;
  }

  static TranslationAnswerType _answerTypeWithExpressionFallback(
    TranslationAnswerType value,
    TranslationExpression? expression,
  ) {
    if (expression == null || expression.isEmpty) return value;
    return switch (value) {
      TranslationAnswerType.wordTranslation || TranslationAnswerType.unknown =>
        TranslationAnswerType.expressionExplanation,
      _ => value,
    };
  }

  static TranslationExpression? _normalizeExpressionClassification(
    TranslationExpression? expression, {
    required String selectedText,
  }) {
    if (expression == null || expression.isEmpty) return expression;
    if (!_looksLikeNonPhrasalExpression(expression)) return expression;

    final selectedRole = _claimsParticleRole(expression.selectedRole)
        ? _nonPhrasalSelectedRole(selectedText)
        : expression.selectedRole;
    final expressionType = _claimsPhrasalVerb(expression.expressionType)
        ? 'fixed_expression'
        : expression.expressionType;
    final constructionType = _claimsPhrasalVerb(expression.constructionType)
        ? null
        : expression.constructionType;
    final canonicalPattern = _nonPhrasalCanonicalPattern(expression);

    return TranslationExpression(
      term: expression.term,
      normalizedExpression: expression.normalizedExpression,
      expressionType: expressionType,
      selectedRole: selectedRole,
      constructionType: constructionType,
      surface: expression.surface,
      lexicalUnit: expression.lexicalUnit,
      canonicalPattern: canonicalPattern,
      isSelectedPartOfLexicalUnit: expression.isSelectedPartOfLexicalUnit,
      isMultiwordExpression: expression.isMultiwordExpression,
      partOfSpeech: expression.partOfSpeech,
      register: expression.register,
      domain: expression.domain,
    );
  }

  static bool _looksLikeNonPhrasalExpression(
    TranslationExpression expression,
  ) {
    final expressionText = _expressionComparableText(expression);
    if (expressionText == null) return false;
    final tokens = expressionText.split(' ');
    if (tokens.isEmpty) return false;
    final startsWithFunctionWord = _nonVerbExpressionOpeners.contains(
      tokens.first,
    );
    final hasVerbObjectSlot = _normalizeForComparison(
      expression.canonicalPattern ?? '',
    ).contains('[object]');
    return startsWithFunctionWord && !hasVerbObjectSlot;
  }

  static String? _expressionComparableText(TranslationExpression expression) {
    for (final value in [
      expression.surface,
      expression.lexicalUnit,
      expression.normalizedExpression,
      expression.canonicalPattern,
    ]) {
      final normalized = _normalizeForComparison(value ?? '');
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static String? _nonPhrasalCanonicalPattern(
    TranslationExpression expression,
  ) {
    final pattern = expression.canonicalPattern;
    if (pattern == null) return null;
    final normalizedPattern = _normalizeForComparison(pattern);
    if (normalizedPattern.isEmpty) return null;
    if (normalizedPattern.contains('[object]') ||
        normalizedPattern.contains('{object}')) {
      return pattern;
    }
    final head = _normalizeForComparison(
      expression.surface ??
          expression.lexicalUnit ??
          expression.normalizedExpression ??
          '',
    );
    return normalizedPattern == head ? null : pattern;
  }

  static String _nonPhrasalSelectedRole(String selectedText) {
    final selected = _normalizeForComparison(selectedText);
    if (_nonVerbExpressionOpeners.contains(selected)) return 'component';
    return 'component';
  }

  static bool _claimsParticleRole(String? value) {
    final normalized = _normalizeForComparison(value ?? '');
    return normalized == 'particle' || normalized.contains('particle');
  }

  static bool _claimsPhrasalVerb(String? value) {
    final normalized = _normalizeForComparison(value ?? '');
    return normalized.contains('phrasal verb') ||
        normalized.contains('phrasal_verb');
  }

  static const _nonVerbExpressionOpeners = {
    'aboard',
    'about',
    'above',
    'across',
    'after',
    'against',
    'along',
    'among',
    'around',
    'as',
    'at',
    'because',
    'before',
    'behind',
    'below',
    'beneath',
    'beside',
    'between',
    'beyond',
    'by',
    'despite',
    'down',
    'during',
    'for',
    'from',
    'in',
    'inside',
    'into',
    'like',
    'near',
    'of',
    'off',
    'on',
    'onto',
    'opposite',
    'out',
    'outside',
    'over',
    'past',
    'since',
    'than',
    'through',
    'throughout',
    'to',
    'toward',
    'under',
    'underneath',
    'until',
    'up',
    'upon',
    'with',
    'within',
    'without',
  };

  static TranslationExpression? _expressionFromSenseFallback(
    TranslationSense? sense, {
    required String fallbackTerm,
  }) {
    final phrase = _quotedPhraseFromSense(sense, fallbackTerm: fallbackTerm);
    if (phrase == null) return null;
    final evidence = [
      sense?.sourceDefinition,
      sense?.sourceContextNote,
      sense?.targetDefinition,
      sense?.targetContextNote,
    ].whereType<String>().join(' ').toLowerCase();
    final type = evidence.contains('phrasal verb')
        ? 'phrasal_verb'
        : evidence.contains('idiom')
        ? 'idiom'
        : 'fixed_expression';
    return TranslationExpression(
      term: fallbackTerm,
      normalizedExpression: phrase,
      expressionType: type,
      selectedRole: 'component',
      surface: phrase,
      lexicalUnit: phrase,
      isSelectedPartOfLexicalUnit: true,
      isMultiwordExpression: true,
    );
  }

  static String? _quotedPhraseFromSense(
    TranslationSense? sense, {
    required String fallbackTerm,
  }) {
    if (sense == null || fallbackTerm.trim().isEmpty) return null;
    final candidates = [
      sense.sourceContextNote,
      sense.sourceDefinition,
      sense.targetContextNote,
      sense.targetDefinition,
    ].whereType<String>();
    final pattern = RegExp(
      r'''\b(?:phrase|expression|idiom|construction|collocation|term|фраз[аы]|выражени[ея])\s+["'“‘]([^"'”’]+)["'”’]''',
      caseSensitive: false,
    );
    for (final candidate in candidates) {
      for (final match in pattern.allMatches(candidate)) {
        final phrase = match.group(1)?.trim();
        if (_phraseContainsSelection(phrase, fallbackTerm)) return phrase;
      }
    }
    return null;
  }

  static bool _phraseContainsSelection(String? phrase, String selectedText) {
    if (phrase == null || phrase.trim().isEmpty) return false;
    final normalizedPhrase = _normalizeForComparison(phrase);
    final normalizedSelection = _normalizeForComparison(selectedText);
    if (normalizedSelection.isEmpty ||
        normalizedPhrase == normalizedSelection) {
      return false;
    }
    final tokenPattern = RegExp(
      '(^|\\s)${RegExp.escape(normalizedSelection)}(\\s|\$)',
    );
    return tokenPattern.hasMatch(normalizedPhrase) ||
        normalizedPhrase.contains(normalizedSelection);
  }

  static TranslationExpression? _expressionFromRoot(
    Map<String, Object?> value, {
    required String fallbackTerm,
  }) {
    final mode = _nonEmptyString(value['mode']);
    if (mode == 'single_word' || mode == 'span_translation') return null;

    final hasExpressionMetadata =
        _nonEmptyString(value['term']) != null ||
        _nonEmptyString(value['normalized_expression']) != null ||
        _nonEmptyString(value['expression_type']) != null ||
        _bool(value['is_multiword_expression']) != null ||
        _nonEmptyString(value['part_of_speech']) != null ||
        _nonEmptyString(value['register']) != null ||
        _nonEmptyString(value['domain']) != null;
    if (!hasExpressionMetadata) return null;

    final expression = TranslationExpression(
      term: _nonEmptyString(value['term']) ?? fallbackTerm,
      normalizedExpression: _nonEmptyString(value['normalized_expression']),
      expressionType: _nonEmptyString(value['expression_type']),
      isMultiwordExpression: _bool(value['is_multiword_expression']),
      partOfSpeech: _nonEmptyString(value['part_of_speech']),
      register: _nonEmptyString(value['register']),
      domain: _nonEmptyString(value['domain']),
    );
    return expression.isEmpty ? null : expression;
  }

  static String? _contextFromExpression(
    Object? value, {
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    if (value is! Map<String, Object?>) return null;

    final sourceExplanation = _nonEmptyString(value['source_explanation']);
    final targetExplanation = _nonEmptyString(value['target_explanation']);
    if (sourceExplanation == null && targetExplanation == null) return null;

    final parts = <String>[
      if (sourceExplanation != null)
        'Source ($sourceLanguage): $sourceExplanation',
      if (targetExplanation != null)
        'Target ($targetLanguage): $targetExplanation',
    ];
    return parts.join(' ');
  }

  static String? _selectedTextTranslation({
    required String? modelTranslatedText,
    required String? literalTranslation,
    required String originalText,
    required TranslationAnswerType answerType,
    required TranslationExpression? expression,
  }) {
    if (answerType == TranslationAnswerType.expressionExplanation &&
        literalTranslation != null &&
        !_selectionCoversExpression(originalText, expression)) {
      return literalTranslation;
    }
    return modelTranslatedText;
  }

  static bool _selectionCoversExpression(
    String originalText,
    TranslationExpression? expression,
  ) {
    final selected = _normalizeForComparison(originalText);
    if (selected.isEmpty || expression == null) return true;

    final expressionValues = [
      expression.surface,
      expression.lexicalUnit,
      expression.normalizedExpression,
    ].whereType<String>().map(_normalizeForComparison);
    return expressionValues.any((value) => value == selected);
  }

  static String _normalizeForComparison(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _usageExamples(
    Map<String, Object?> decoded, {
    required TranslationExpression? expression,
  }) {
    final examples = <String>[];

    final markedSentence = _nonEmptyString(decoded['marked_sentence']);
    if (markedSentence != null) {
      examples.add(markedSentence);
    }

    final usageExamples = decoded['usage_examples'];
    if (usageExamples is List) {
      examples.addAll(usageExamples.whereType<String>());
    }

    final legacyExamples = decoded['examples'];
    if (legacyExamples is List) {
      examples.addAll(
        legacyExamples.map((value) {
          if (value is String) return value;
          if (value is Map<String, Object?>) {
            return _nonEmptyString(value['source']);
          }
          return null;
        }).whereType<String>(),
      );
    }

    if (examples.isEmpty) return const [];
    return _filterUsageExamples(examples, expression: expression);
  }

  static List<String> _filterUsageExamples(
    Iterable<String> values, {
    required TranslationExpression? expression,
  }) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((value) => _matchesExpressionExample(value, expression))
        .map(
          (value) => _normalizeUsageExampleHighlight(
            value,
            expression: expression,
          ),
        );
    return _deduplicateStrings(normalized, limit: 4);
  }

  static String _normalizeUsageExampleHighlight(
    String value, {
    required TranslationExpression? expression,
  }) {
    final pattern = _requiredSeparatedPhrasalPattern(expression);
    if (pattern == null) return value;

    final plain = value.replaceAll(RegExp(r'\[\[|\]\]'), '');
    final span = _separatedPhrasalSpan(plain, pattern);
    if (span == null) return value;
    return '${plain.substring(0, span.start)}[[${plain.substring(span.start, span.end)}]]${plain.substring(span.end)}';
  }

  static _TextSpan? _separatedPhrasalSpan(
    String value,
    _SeparatedPhrasalPattern pattern,
  ) {
    final spans = _englishTokenSpans(value);
    if (spans.isEmpty) return null;
    for (var index = 0; index < spans.length; index += 1) {
      if (!_isVerbForm(spans[index].token, pattern.verb)) continue;
      final minParticleIndex = index + 2;
      final lastParticleStart = spans.length - pattern.particles.length;
      final maxParticleIndex = [
        lastParticleStart,
        index + 8,
      ].reduce((a, b) => a < b ? a : b);
      for (
        var particleIndex = minParticleIndex;
        particleIndex <= maxParticleIndex;
        particleIndex += 1
      ) {
        if (_matchesParticleSpanSequence(
          spans,
          particleIndex,
          pattern.particles,
        )) {
          return _TextSpan(
            spans[index].start,
            spans[particleIndex + pattern.particles.length - 1].end,
          );
        }
      }
    }
    return null;
  }

  static bool _matchesParticleSpanSequence(
    List<_TokenSpan> spans,
    int start,
    List<String> particles,
  ) {
    if (start < 0 || start + particles.length > spans.length) return false;
    for (var index = 0; index < particles.length; index += 1) {
      if (spans[start + index].token != particles[index]) return false;
    }
    return true;
  }

  static List<_TokenSpan> _englishTokenSpans(String value) {
    return RegExp(r'[A-Za-z]+')
        .allMatches(value)
        .map(
          (match) => _TokenSpan(
            match.group(0)!.toLowerCase(),
            match.start,
            match.end,
          ),
        )
        .toList(growable: false);
  }

  static bool _matchesExpressionExample(
    String value,
    TranslationExpression? expression,
  ) {
    final pattern = _requiredSeparatedPhrasalPattern(expression);
    if (pattern == null) return true;
    return _containsSeparatedPhrasalPattern(
      _englishTokens(value.replaceAll(RegExp(r'\[\[|\]\]'), '')),
      pattern,
    );
  }

  static _SeparatedPhrasalPattern? _requiredSeparatedPhrasalPattern(
    TranslationExpression? expression,
  ) {
    final pattern = _separatedPhrasalPattern(expression?.canonicalPattern);
    if (pattern == null) return null;

    final surfaceTokens = _englishTokens(expression?.surface ?? '');
    if (surfaceTokens.isEmpty) return null;
    final surfaceIsSeparated = _containsSeparatedPhrasalPattern(
      surfaceTokens,
      pattern,
    );
    return surfaceIsSeparated ? pattern : null;
  }

  static _SeparatedPhrasalPattern? _separatedPhrasalPattern(String? value) {
    final tokens = _englishTokens(value ?? '');
    if (tokens.length < 3) return null;
    final placeholderIndex = tokens.indexWhere(_isPhrasalObjectPlaceholder);
    if (placeholderIndex <= 0 || placeholderIndex >= tokens.length - 1) {
      return null;
    }
    final particles = tokens.sublist(placeholderIndex + 1);
    if (particles.isEmpty) return null;
    return _SeparatedPhrasalPattern(
      verb: tokens.first,
      particles: particles,
    );
  }

  static bool _isPhrasalObjectPlaceholder(String token) {
    return const {
      'object',
      'someone',
      'somebody',
      'something',
      'somewhere',
      'sth',
      'sb',
      'person',
      'people',
      'thing',
      'noun',
      'pronoun',
      'np',
      'one',
      'oneself',
    }.contains(token);
  }

  static List<String> _englishTokens(String value) {
    return _normalizeForComparison(value)
        .split(RegExp(r'[^a-z]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static bool _containsSeparatedPhrasalPattern(
    List<String> tokens,
    _SeparatedPhrasalPattern pattern,
  ) {
    for (var index = 0; index < tokens.length; index += 1) {
      if (!_isVerbForm(tokens[index], pattern.verb)) continue;
      final minParticleIndex = index + 2;
      final lastParticleStart = tokens.length - pattern.particles.length;
      final maxParticleIndex = [
        lastParticleStart,
        index + 8,
      ].reduce((a, b) => a < b ? a : b);
      for (
        var particleIndex = minParticleIndex;
        particleIndex <= maxParticleIndex;
        particleIndex += 1
      ) {
        if (_matchesParticleSequence(
          tokens,
          particleIndex,
          pattern.particles,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _matchesParticleSequence(
    List<String> tokens,
    int start,
    List<String> particles,
  ) {
    if (start < 0 || start + particles.length > tokens.length) return false;
    for (var index = 0; index < particles.length; index += 1) {
      if (tokens[start + index] != particles[index]) return false;
    }
    return true;
  }

  static bool _isVerbForm(String token, String verb) {
    if (token == verb) return true;
    final forms = <String>{
      '${verb}s',
      '${verb}ed',
      '${verb}ing',
    };
    if (verb.endsWith('e') && verb.length > 1) {
      forms.add('${verb.substring(0, verb.length - 1)}ing');
    }
    if (verb.endsWith('y') && verb.length > 1) {
      forms.add('${verb.substring(0, verb.length - 1)}ies');
    }
    return forms.contains(token);
  }

  static List<String> _naturalEquivalentsFromDecoded(
    Map<String, Object?> decoded, {
    required String originalText,
    required TranslationExpression? expression,
  }) {
    return _deduplicateStrings([
      ..._naturalEquivalents(decoded['natural_equivalents']),
      ..._relatedTerms(
        decoded['related_terms'],
        originalText: originalText,
        expression: expression,
      ),
    ]);
  }

  static List<String> _relatedTerms(
    Object? value, {
    required String originalText,
    required TranslationExpression? expression,
  }) {
    if (value is! List) return const [];
    return _deduplicateStrings(
      value.map((item) {
        if (item is! Map<String, Object?>) return null;
        final relation = _nonEmptyString(item['relation'])?.toLowerCase();
        if (!_allowedRelatedTermRelation(relation)) return null;
        final source = _nonEmptyString(item['source']);
        if (source == null) return null;
        if (_repeatsSelectedHeadword(
          source,
          originalText: originalText,
          expression: expression,
        )) {
          return null;
        }
        return _relatedTermLabel(item);
      }).whereType<String>(),
    );
  }

  static bool _allowedRelatedTermRelation(String? relation) {
    return relation == 'word_family' ||
        relation == 'domain_collocation' ||
        relation == 'contrast_term' ||
        relation == 'narrower_domain_term';
  }

  static bool _repeatsSelectedHeadword(
    String source, {
    required String originalText,
    required TranslationExpression? expression,
  }) {
    final normalizedSource = _normalizeForRelatedTerm(source);
    if (normalizedSource.isEmpty) return false;

    final compactSource = _compactForRelatedTerm(normalizedSource);
    final references = _relatedTermReferenceValues(
      originalText: originalText,
      expression: expression,
    );
    for (final reference in references) {
      if (reference.length < 4) continue;
      final compactReference = _compactForRelatedTerm(reference);
      if (compactReference.length < 4) continue;
      if (compactSource == compactReference ||
          compactSource.contains(compactReference)) {
        return true;
      }
      if (_containsWholeRelatedTermReference(normalizedSource, reference)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _relatedTermReferenceValues({
    required String originalText,
    required TranslationExpression? expression,
  }) {
    final values = <String>[
      originalText,
      if (expression != null) ...[
        if (expression.term != null) expression.term!,
        if (expression.surface != null) expression.surface!,
        if (expression.lexicalUnit != null) expression.lexicalUnit!,
        if (expression.normalizedExpression != null)
          expression.normalizedExpression!,
      ],
    ];
    final references = <String>[];
    for (final value in values) {
      final normalized = _normalizeForRelatedTerm(value);
      if (normalized.length >= 4) references.add(normalized);
      for (final token in normalized.split(RegExp(r'[^a-z0-9]+'))) {
        if (token.length < 4) continue;
        references.add(token);
        if (token.endsWith('s') && token.length > 4) {
          references.add(token.substring(0, token.length - 1));
        }
      }
    }
    return _deduplicateStrings(references);
  }

  static String _normalizeForRelatedTerm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

  static String _compactForRelatedTerm(String value) =>
      value.replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static bool _containsWholeRelatedTermReference(
    String source,
    String reference,
  ) {
    if (reference.length < 4) return false;
    final pattern = RegExp(
      '(^|[^a-z0-9])${RegExp.escape(reference)}([^a-z0-9]|\$)',
    );
    return pattern.hasMatch(source);
  }

  static List<String> _naturalEquivalents(Object? value) {
    if (value is List) {
      return _deduplicateStrings(
        value.map((item) {
          if (item is String) return item;
          if (item is Map<String, Object?>) return _relatedTermLabel(item);
          return null;
        }).whereType<String>(),
      );
    }
    if (value is Map<String, Object?>) {
      final target = value['target'];
      if (target is List) return _stringList(target);
    }
    return const [];
  }

  static String? _relatedTermLabel(Map<String, Object?> value) {
    final source = _nonEmptyString(value['source']);
    final target = _nonEmptyString(value['target']);
    if (source == null) return target;
    if (target == null) return source;
    return '$source — $target';
  }

  static List<String> _stringList(List<Object?> value) => _deduplicateStrings(
    value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );

  static List<String> _deduplicateStrings(
    Iterable<String> values, {
    int? limit,
  }) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final key = _normalizeForComparison(value);
      if (!seen.add(key)) continue;
      result.add(value);
      if (limit != null && result.length >= limit) break;
    }
    return result.toList(growable: false);
  }

  static TranslationTextPair? _suggestedFullPhraseFromMinimalPayload(
    Map<String, Object?> decoded,
  ) {
    final phrase = decoded['phrase'];
    if (phrase is! Map<String, Object?>) return null;
    final target =
        _targetString(phrase['translation']) ??
        _targetString(decoded['phrase_translation']) ??
        _targetString(decoded['expression_translation']) ??
        _targetString(decoded['contextual_translation']) ??
        _targetString(decoded['translation']);
    if (target == null) return null;
    final source =
        _nonEmptyString(phrase['text']) ??
        _nonEmptyString(phrase['source']) ??
        _nonEmptyString(phrase['surface']);
    return TranslationTextPair(source: source, target: target);
  }

  static TranslationTextPair? _suggestedFullPhrase(
    Map<String, Object?> decoded,
    TranslationExpression? expression,
  ) {
    final pair = _pairFromMap(decoded['suggested_full_phrase']);
    if (pair == null) return null;
    if (pair.source != null || pair.target == null) return pair;
    final fallbackSource = expression?.surface;
    if (fallbackSource == null || fallbackSource.trim().isEmpty) return pair;
    return TranslationTextPair(source: fallbackSource, target: pair.target);
  }

  static TranslationTextPair? _suggestedFullPhraseFromSenseFallback(
    TranslationSense? sense,
    TranslationExpression? expression, {
    required String originalText,
  }) {
    if (expression == null ||
        _selectionCoversExpression(originalText, expression)) {
      return null;
    }
    final source =
        expression.surface ??
        expression.lexicalUnit ??
        expression.normalizedExpression;
    if (source == null || source.trim().isEmpty) return null;
    return TranslationTextPair(source: source, target: sense?.targetDefinition);
  }

  static TranslationTextPair? _pairFromMap(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final pair = TranslationTextPair(
      source: _sourceString(value),
      target: _targetString(value),
    );
    return pair.isEmpty ? null : pair;
  }

  static String? _sourceString(Object? value) {
    if (value is Map<String, Object?>) return _nonEmptyString(value['source']);
    return null;
  }

  static String? _targetString(Object? value) {
    if (value is String) return _nonEmptyString(value);
    if (value is Map<String, Object?>) return _nonEmptyString(value['target']);
    return null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _ipaString(Object? value) {
    final trimmed = _nonEmptyString(value);
    if (trimmed == null) return null;
    if (trimmed.startsWith('/') && trimmed.endsWith('/')) return trimmed;
    return '/$trimmed/';
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  static TranslationAnswerType _answerTypeFromString(Object? value) {
    final normalized = _nonEmptyString(value)?.toLowerCase();
    return switch (normalized) {
      'word_translation' => TranslationAnswerType.wordTranslation,
      'expression_explanation' => TranslationAnswerType.expressionExplanation,
      'span_translation' => TranslationAnswerType.spanTranslation,
      'ambiguous' => TranslationAnswerType.ambiguous,
      _ => TranslationAnswerType.unknown,
    };
  }

  static TranslationAnswerType _answerTypeWithModeFallback(
    TranslationAnswerType value,
    Object? mode,
  ) {
    if (value != TranslationAnswerType.unknown) return value;
    return _answerTypeFromMode(mode);
  }

  static TranslationAnswerType _answerTypeFromMode(Object? value) {
    final normalized = _nonEmptyString(value)?.toLowerCase();
    return switch (normalized) {
      'single_word' => TranslationAnswerType.wordTranslation,
      'word_in_expression' => TranslationAnswerType.expressionExplanation,
      'selected_expression' => TranslationAnswerType.expressionExplanation,
      'span_translation' => TranslationAnswerType.spanTranslation,
      _ => TranslationAnswerType.unknown,
    };
  }

  static TranslationConfidence _confidenceFromString(Object? value) {
    final normalized = _nonEmptyString(value)?.toLowerCase();
    return switch (normalized) {
      'high' => TranslationConfidence.high,
      'medium' => TranslationConfidence.medium,
      'low' => TranslationConfidence.low,
      _ => TranslationConfidence.unknown,
    };
  }

  static TranslationResult? decodeModelPayloadForTesting(
    String content, {
    String originalText = '',
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final decoded = _decodeModelPayload(
      content,
      originalText: originalText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    final translatedText = decoded.translatedText;
    if (translatedText == null) return null;
    return decoded.toTranslationResult(
      originalText: originalText,
      translatedText: translatedText,
    );
  }

  static String? markedContextForTesting({
    required String selectedText,
    String? contextText,
  }) => _buildMarkedContext(
    selectedText: selectedText.trim(),
    contextText: contextText?.trim(),
  );

  static String get systemPromptForTesting => _systemPrompt;

  static String _stripSelectionMarkers(String value) {
    return value.replaceAll('[[', '').replaceAll(']]', '').trim();
  }

  static _MarkedContextWindow _markedContextWindow(String value) {
    final text = _collapseWhitespace(value);
    final markerStart = text.indexOf('[[');
    final markerEnd = markerStart < 0 ? -1 : text.indexOf(']]', markerStart);
    if (markerStart < 0 || markerEnd < markerStart) {
      return _MarkedContextWindow(current: text);
    }

    final currentStart = _sentenceStartBefore(text, markerStart);
    final currentEnd = _sentenceEndAfter(text, markerEnd + 2);
    final previous = _sentenceBefore(text, currentStart);
    final current = text.substring(currentStart, currentEnd).trim();
    final next = _sentenceAfter(text, currentEnd);
    return _MarkedContextWindow(
      previous: previous,
      current: current,
      next: next,
    );
  }

  static String _collapseWhitespace(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static int _sentenceStartBefore(String value, int index) {
    for (var i = index - 1; i >= 0; i -= 1) {
      if (_isSentenceTerminator(value.codeUnitAt(i))) {
        return _skipWhitespaceForward(value, i + 1);
      }
    }
    return 0;
  }

  static int _sentenceEndAfter(String value, int index) {
    for (var i = index; i < value.length; i += 1) {
      if (_isSentenceTerminator(value.codeUnitAt(i))) {
        return i + 1;
      }
    }
    return value.length;
  }

  static String? _sentenceBefore(String value, int currentStart) {
    var end = currentStart;
    while (end > 0 && value.codeUnitAt(end - 1) == 0x20) {
      end -= 1;
    }
    if (end <= 0) return null;
    final start = _sentenceStartBefore(value, end - 1);
    final sentence = value.substring(start, end).trim();
    return sentence.isEmpty ? null : sentence;
  }

  static String? _sentenceAfter(String value, int currentEnd) {
    final start = _skipWhitespaceForward(value, currentEnd);
    if (start >= value.length) return null;
    final end = _sentenceEndAfter(value, start);
    final sentence = value.substring(start, end).trim();
    return sentence.isEmpty ? null : sentence;
  }

  static int _skipWhitespaceForward(String value, int index) {
    var current = index;
    while (current < value.length && value.codeUnitAt(current) == 0x20) {
      current += 1;
    }
    return current;
  }

  static bool _isSentenceTerminator(int codeUnit) =>
      codeUnit == 0x2e || // .
      codeUnit == 0x21 || // !
      codeUnit == 0x3f || // ?
      codeUnit == 0x3002 || // 。
      codeUnit == 0xff01 || // ！
      codeUnit == 0xff1f; // ？

  static String? _buildMarkedContext({
    required String selectedText,
    String? contextText,
  }) {
    final context = contextText?.trim();
    if (context == null || context.isEmpty) return null;
    if (selectedText.isEmpty) return context;
    if (context.contains('[[') && context.contains(']]')) return context;

    final index = _findSelectionIndex(context, selectedText);
    if (index < 0) return context;

    final end = index + selectedText.length;
    return '${context.substring(0, index)}[[${context.substring(index, end)}]]${context.substring(end)}';
  }

  static int _findSelectionIndex(String context, String selectedText) {
    final exactIndex = _findSelectionIndexWithBoundary(
      context,
      selectedText,
      caseSensitive: true,
    );
    if (exactIndex >= 0) return exactIndex;

    final insensitiveIndex = _findSelectionIndexWithBoundary(
      context,
      selectedText,
      caseSensitive: false,
    );
    if (insensitiveIndex >= 0) return insensitiveIndex;

    final fallbackExact = context.indexOf(selectedText);
    if (fallbackExact >= 0) return fallbackExact;
    return context.toLowerCase().indexOf(selectedText.toLowerCase());
  }

  static int _findSelectionIndexWithBoundary(
    String context,
    String selectedText, {
    required bool caseSensitive,
  }) {
    final haystack = caseSensitive ? context : context.toLowerCase();
    final needle = caseSensitive ? selectedText : selectedText.toLowerCase();
    var start = 0;
    while (start < haystack.length) {
      final index = haystack.indexOf(needle, start);
      if (index < 0) return -1;
      final end = index + needle.length;
      if (_hasTokenBoundaries(context, index, end)) return index;
      start = index + 1;
    }
    return -1;
  }

  static bool _hasTokenBoundaries(String value, int start, int end) {
    final startsWithWord = _isAsciiWord(value.codeUnitAt(start));
    final endsWithWord = _isAsciiWord(value.codeUnitAt(end - 1));
    if (startsWithWord &&
        start > 0 &&
        _isAsciiWord(value.codeUnitAt(start - 1))) {
      return false;
    }
    if (endsWithWord &&
        end < value.length &&
        _isAsciiWord(value.codeUnitAt(end))) {
      return false;
    }
    return true;
  }

  static bool _isAsciiWord(int codeUnit) =>
      codeUnit == 0x5f ||
      codeUnit >= 0x30 && codeUnit <= 0x39 ||
      codeUnit >= 0x41 && codeUnit <= 0x5a ||
      codeUnit >= 0x61 && codeUnit <= 0x7a;

  static String _extractJsonObject(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    final first = trimmed.indexOf('{');
    final last = trimmed.lastIndexOf('}');
    if (first < 0 || last <= first) {
      throw const FormatException('Missing JSON object in model response');
    }
    return trimmed.substring(first, last + 1);
  }

  static const _systemPrompt = '''
You are a contextual bilingual translator for a reading app.

Input JSON contains source_language, target_language, selected_text, and usually marked_context where the selected span is wrapped in [[...]]. When context is present, context.current is the source sentence containing the selection, and context.previous/context.next are neighboring source sentences when available. Use neighboring context only to choose the meaning of the selected text.

Return JSON only. Do not use Markdown. Do not add keys outside the selected response shape.

Rules:
- Choose the response mode first. Do not choose single_word until all larger-unit checks below fail.
- context.current is primary. context.previous/context.next are only supporting context for ambiguity, not material to translate as the answer.
- A selected word may still be part of a larger unit. If it is part of a phrasal verb, idiom, fixed phrase, collocation, verb pattern, preposition pattern, or sentence pattern in context.current, return word_in_expression.
- This applies to any selected word/span inside the larger unit, including the semantic head or an ordinary standalone noun/verb/adjective. Do not treat a headword as single_word just because it has an independent dictionary meaning. The English examples are illustrative only; apply the same rule for every source_language and script. For languages without whitespace word boundaries, treat the selected lexical segment the same way. Correct examples: selected night in a night out -> word_in_expression, phrase.text = "a night out"; selected out in a night out -> word_in_expression, phrase.text = "a night out"; selected way in out of the way -> word_in_expression, phrase.text = "out of the way".
- Direct selected-text translation comes first in the output, but it is not a mode-selection rule. For word_in_expression, word_translation is the direct translation of the exact selected token in its grammatical role before applying the larger-unit meaning from context.current, not the contextual meaning of the larger phrase and not an unrelated homograph/part of speech. Never put the larger expression meaning in word_translation. If this makes the main translation look odd, it is still correct because the expression meaning belongs in definition.target. Correct examples: selected kick in kick things off -> word_translation пинать, not начинать; selected turn in turn the projector off -> word_translation поворачивать, not выключать; selected fading in fading out the top image -> word_translation затухание or исчезновение, not увядание; selected carried in carried on -> word_translation нес or перенес, not продолжал; selected backed in backed out of the agreement -> word_translation отступил or сдал назад, not поддержанный; selected up in look the term up -> word_translation вверх, not искать.
- Return single_word only when the selected word is ordinary in context.current and is not part of any larger unit. For single_word, define the selected word sense, not the whole sentence.
- transcription is slash-delimited IPA for the exact selected word, for example /feɪd/. For ordinary English words, provide IPA when the word has a standard pronunciation; use null only for names, symbols, abbreviations, or words whose pronunciation is genuinely unknown.
- word_form/lemma are only for inflectional forms, not derivationally related words. Use them for plural nouns, irregular plurals, gerunds/present participles, past-tense verbs, comparatives, and superlatives. Do not use them for adverb/adjective derivations such as optimistically -> optimistic; put such relations in related_terms only when useful. For plural nouns and irregular plurals, lemma must be the singular noun and lemma_transcription must be the singular slash-delimited IPA. For gerunds/present participles and past-tense verbs, lemma must be the infinitive/base verb and lemma_transcription must be the base slash-delimited IPA. Use null only when the selected word is already the dictionary form. Inflected examples that must not return null: children -> lemma child, grammatical_form plural; analyses -> lemma analysis, grammatical_form plural; fading -> lemma fade, grammatical_form gerund; resolved -> lemma resolve, grammatical_form past_tense.
- If a selected function word is governed by a nearby lexical head in context.current, classify the whole construction as word_in_expression: interested in, responsible for, prevent from, depend on, on behalf of, in charge of.
- If one selected word is a lexical verb, also check immediately nearby particles/prepositions in context.current. If the selected verb plus a nearby particle forms a phrasal verb or phrasal-verb construction, return word_in_expression. This applies to inflected verb forms too: fading out, looked up, turning off, carried on.
- For phrasal verbs with an object after the particle, phrase.text should include the verb plus particle, not the object: selected fading in fading out the top image -> phrase.text = "fading out". For separated object constructions, phrase.text and marked_sentence should include the full surface span: kicked the project off.
- For word_in_expression and selected_expression, return a concise contextual target-language translation of the whole phrase/idiom/collocation separately from definitions. This must be a natural dictionary translation such as "ворваться", not an explanatory definition such as "внезапно и с силой войти в помещение".
- Source definitions and marked_sentence must stay in source_language.
- Target translations and target definitions must stay in target_language.
- usage_examples must stay in source_language, use [[...]] around the same selected word/span or larger unit, and return 1-3 concise examples or [] when none are useful.
- related_terms are vocabulary aids, not alternative translations and not translation explanations.
- related_terms items must be source/target term pairs: source stays in source_language, target stays in target_language, relation is word_family|domain_collocation|contrast_term|narrower_domain_term.
- related_terms.source must be a concise source term or established source collocation from the same lexical/domain field.
- Do not include synonyms, near-synonyms, broad paraphrases, definition-derived phrases, role labels, or generic related concepts in related_terms.
- Do not include related_terms whose source repeats or contains the selected word, selected headword, or expression headword.
- Prefer terms that teach useful vocabulary boundaries: word-family forms, common domain collocations, narrower terms, or contrast terms that are often confused with the selected term. If unsure, return [].
- Highlight the larger unit only when the selected word is part of one; otherwise highlight the exact selection.
- For separated phrasal verbs, phrase.text and marked_sentence highlight the full separated construction, for example [[kicked the project off]]. Do not imply an inserted object is part of the dictionary phrasal verb.

If one selected word is part of a larger unit, return:
{
  "mode": "word_in_expression",
  "word": "exact selected word",
  "word_translation": "target-language translation of the exact word",
  "word_form": {"lemma": "dictionary form for inflected selected word", "form": "plural|gerund|past_tense|comparative|superlative", "transcription": "slash-delimited IPA for lemma"} or null,
  "definition": {"source": "source-language definition of the contextual unit", "target": "target-language definition of the contextual unit"},
  "phrase": {"text": "larger source phrase or construction span to highlight", "translation": "concise target-language translation of the whole contextual unit", "type": "phrasal_verb|idiom|fixed_phrase|collocation|verb_pattern|preposition_pattern|sentence_pattern"},
  "marked_sentence": "source sentence with [[larger phrase]] highlighted",
  "usage_examples": ["source-language usage example with [[larger phrase]] highlighted"],
  "related_terms": [{"source": "source-language related term", "target": "target-language translation", "relation": "word_family|domain_collocation|contrast_term|narrower_domain_term"}]
}

If one selected word is ordinary in this context, return:
{
  "mode": "single_word",
  "word": "exact selected word",
  "word_translation": "target-language translation of the exact word",
  "part_of_speech": "noun|verb|adjective|adverb|preposition|pronoun|determiner|conjunction|interjection|other",
  "transcription": "slash-delimited IPA for exact selected word" or null,
  "lemma": "dictionary/base form for inflected selected word" or null,
  "lemma_transcription": "slash-delimited IPA for lemma" or null,
  "grammatical_form": "plural|gerund|past_tense|comparative|superlative" or null,
  "word_form": {"lemma": "same as lemma; required for plural, gerund, past_tense, comparative, superlative", "form": "same as grammatical_form", "transcription": "same as lemma_transcription"} or null,
  "definition": {"source": "source-language definition of this word sense", "target": "target-language definition of this word sense"},
  "marked_sentence": "source sentence with [[selected word]] highlighted",
  "usage_examples": ["source-language usage example with [[selected word]] highlighted"],
  "related_terms": [{"source": "source-language related term", "target": "target-language translation", "relation": "word_family|domain_collocation|contrast_term|narrower_domain_term"}]
}

If the selected n-word text is itself a larger unit, return:
{
  "mode": "selected_expression",
  "text": "exact selected text",
  "translation": "concise contextual target-language translation, not a definition",
  "phrase_type": "phrasal_verb|idiom|fixed_phrase|collocation|verb_pattern|preposition_pattern|sentence_pattern",
  "definition": {"source": "source-language definition of the selected unit", "target": "target-language definition of the selected unit"},
  "marked_sentence": "source sentence with [[selected text]] highlighted",
  "usage_examples": ["source-language usage example with [[selected text]] highlighted"],
  "related_terms": [{"source": "source-language related term", "target": "target-language translation", "relation": "word_family|domain_collocation|contrast_term|narrower_domain_term"}]
}

If the selected n-word text is not such a unit, return:
{
  "mode": "span_translation",
  "text": "exact selected text",
  "translation": "target-language translation",
  "marked_sentence": "source sentence with [[selected text]] highlighted",
  "usage_examples": ["source-language usage example with [[selected text]] highlighted"],
  "related_terms": [{"source": "source-language related term", "target": "target-language translation", "relation": "word_family|domain_collocation|contrast_term|narrower_domain_term"}]
}

For selected n-word text, choose selected_expression when the selected span itself is a larger unit; otherwise choose span_translation.
''';
}

/// Previous/current/next sentence window sent to the model with `[[...]]`
/// markers around the selected phrase in [current].
class _MarkedContextWindow {
  const _MarkedContextWindow({this.previous, required this.current, this.next});

  final String? previous;
  final String current;
  final String? next;

  String get markedText => [
    previous,
    current,
    next,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  Map<String, String> toPlainJson() => <String, String>{
    if (previous != null) 'previous': _strip(previous!),
    'current': _strip(current),
    if (next != null) 'next': _strip(next!),
  };

  static String _strip(String value) =>
      value.replaceAll('[[', '').replaceAll(']]', '').trim();
}

/// Half-open character range in normalized plain text.
class _TextSpan {
  const _TextSpan(this.start, this.end);

  final int start;
  final int end;
}

/// Token plus its half-open character range in normalized plain text.
class _TokenSpan {
  const _TokenSpan(this.token, this.start, this.end);

  final String token;
  final int start;
  final int end;
}

/// Local parse of a separated phrasal verb pattern, e.g. `look ... up`.
class _SeparatedPhrasalPattern {
  const _SeparatedPhrasalPattern({
    required this.verb,
    required this.particles,
  });

  final String verb;
  final List<String> particles;
}

/// Parsed model response before it is normalized into [TranslationResult].
class _DecodedPayload {
  const _DecodedPayload({
    this.translatedText,
    this.answerType = TranslationAnswerType.unknown,
    this.confidence = TranslationConfidence.unknown,
    this.sense,
    this.expression,
    this.context,
    this.usageExamples = const [],
    this.naturalEquivalents = const [],
    this.literalTranslation,
    this.suggestedFullPhrase,
    this.notes,
  });

  final String? translatedText;
  final TranslationAnswerType answerType;
  final TranslationConfidence confidence;
  final TranslationSense? sense;
  final TranslationExpression? expression;
  final String? context;
  final List<String> usageExamples;
  final List<String> naturalEquivalents;
  final String? literalTranslation;
  final TranslationTextPair? suggestedFullPhrase;
  final TranslationTextPair? notes;

  TranslationResult toTranslationResult({
    required String originalText,
    required String translatedText,
  }) => TranslationResult(
    originalText: originalText,
    translatedText: translatedText,
    source: TranslationSource.remote,
    answerType: answerType,
    confidence: confidence,
    sense: sense,
    expression: expression,
    context: context,
    usageExamples: usageExamples,
    naturalEquivalents: naturalEquivalents,
    literalTranslation: literalTranslation,
    suggestedFullPhrase: suggestedFullPhrase,
    notes: notes,
  );
}
