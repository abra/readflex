import 'package:equatable/equatable.dart';

import 'pronunciation/pronunciation.dart';

/// Source of translation result.
enum TranslationSource { remote, platform }

/// How the model classified the selected reader span.
enum TranslationAnswerType {
  wordTranslation,
  expressionExplanation,
  spanTranslation,
  ambiguous,
  unknown,
}

/// Model confidence for the contextual analysis.
enum TranslationConfidence { high, medium, low, unknown }

/// Source/target definitions and context notes for the selected sense.
class TranslationSense extends Equatable {
  const TranslationSense({
    this.partOfSpeech,
    this.transcription,
    this.lemma,
    this.lemmaTranscription,
    this.grammaticalForm,
    this.sourceDefinition,
    this.targetDefinition,
    this.sourceContextNote,
    this.targetContextNote,
  });

  final String? partOfSpeech;
  final String? transcription;
  final String? lemma;
  final String? lemmaTranscription;
  final String? grammaticalForm;
  final String? sourceDefinition;
  final String? targetDefinition;
  final String? sourceContextNote;
  final String? targetContextNote;

  bool get isEmpty =>
      partOfSpeech == null &&
      transcription == null &&
      lemma == null &&
      lemmaTranscription == null &&
      grammaticalForm == null &&
      sourceDefinition == null &&
      targetDefinition == null &&
      sourceContextNote == null &&
      targetContextNote == null;

  String? toContextString({
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final parts = <String>[
      if (partOfSpeech != null) 'Part of speech: $partOfSpeech',
      if (transcription != null) 'Transcription: $transcription',
      if (lemma != null)
        '${grammaticalForm == 'plural' ? 'Singular' : 'Lemma'}: $lemma${lemmaTranscription == null ? '' : ' $lemmaTranscription'}',
      if (sourceDefinition != null)
        'Source ($sourceLanguage): $sourceDefinition',
      if (targetDefinition != null)
        'Target ($targetLanguage): $targetDefinition',
      if (sourceContextNote != null)
        'Source context ($sourceLanguage): $sourceContextNote',
      if (targetContextNote != null)
        'Target context ($targetLanguage): $targetContextNote',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  List<Object?> get props => [
    partOfSpeech,
    transcription,
    lemma,
    lemmaTranscription,
    grammaticalForm,
    sourceDefinition,
    targetDefinition,
    sourceContextNote,
    targetContextNote,
  ];
}

/// Larger lexical unit detected around the exact user selection.
class TranslationExpression extends Equatable {
  const TranslationExpression({
    this.term,
    this.normalizedExpression,
    this.expressionType,
    this.selectedRole,
    this.constructionType,
    this.surface,
    this.lexicalUnit,
    this.canonicalPattern,
    this.isSelectedPartOfLexicalUnit,
    this.isMultiwordExpression,
    this.partOfSpeech,
    this.register,
    this.domain,
  });

  final String? term;
  final String? normalizedExpression;
  final String? expressionType;
  final String? selectedRole;
  final String? constructionType;
  final String? surface;
  final String? lexicalUnit;
  final String? canonicalPattern;
  final bool? isSelectedPartOfLexicalUnit;
  final bool? isMultiwordExpression;
  final String? partOfSpeech;
  final String? register;
  final String? domain;

  bool get isEmpty =>
      term == null &&
      normalizedExpression == null &&
      expressionType == null &&
      selectedRole == null &&
      constructionType == null &&
      surface == null &&
      lexicalUnit == null &&
      canonicalPattern == null &&
      isSelectedPartOfLexicalUnit == null &&
      isMultiwordExpression == null &&
      partOfSpeech == null &&
      register == null &&
      domain == null;

  @override
  List<Object?> get props => [
    term,
    normalizedExpression,
    expressionType,
    selectedRole,
    constructionType,
    surface,
    lexicalUnit,
    canonicalPattern,
    isSelectedPartOfLexicalUnit,
    isMultiwordExpression,
    partOfSpeech,
    register,
    domain,
  ];
}

/// Source/target phrase pair used for full-expression suggestions or notes.
class TranslationTextPair extends Equatable {
  const TranslationTextPair({this.source, this.target});

  final String? source;
  final String? target;

  bool get isEmpty => source == null && target == null;

  @override
  List<Object?> get props => [source, target];
}

/// Result of a translation request.
class TranslationResult extends Equatable {
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.source,
    this.answerType = TranslationAnswerType.unknown,
    this.confidence = TranslationConfidence.unknown,
    this.sense,
    this.expression,
    this.context,
    this.usageExamples = const [],
    this.naturalEquivalents = const [],
    this.literalTranslation,
    this.expressionTranslation,
    this.suggestedFullPhrase,
    this.notes,
  });

  final String originalText;
  final String translatedText;
  final TranslationSource source;
  final TranslationAnswerType answerType;
  final TranslationConfidence confidence;
  final TranslationSense? sense;
  final TranslationExpression? expression;

  /// Optional contextual explanation from an enriched implementation.
  final String? context;

  /// Optional usage examples from an enriched implementation.
  final List<String> usageExamples;

  /// Optional related source-language terms with target translations,
  /// formatted for display.
  final List<String> naturalEquivalents;

  /// Optional literal target-language rendering when it helps explain idioms.
  final String? literalTranslation;

  /// Optional dictionary-style translation for the expression head or pattern.
  final TranslationTextPair? expressionTranslation;

  /// Optional full expression when the selected text is only part of it.
  final TranslationTextPair? suggestedFullPhrase;

  /// Optional source/target notes for UI details or warnings.
  final TranslationTextPair? notes;

  @override
  List<Object?> get props => [
    originalText,
    translatedText,
    source,
    answerType,
    confidence,
    sense,
    expression,
    context,
    usageExamples,
    naturalEquivalents,
    literalTranslation,
    expressionTranslation,
    suggestedFullPhrase,
    notes,
  ];
}

/// Thrown when a translation implementation cannot produce a result.
class TranslationException implements Exception {
  const TranslationException(this.message);

  final String message;

  @override
  String toString() => 'TranslationException: $message';
}

/// Translation + word-level pronunciation lookup.
///
/// [translate] is cross-language (text → translated text). [lookupPronunciation]
/// is monolingual (word → list of phonetic variants like IPA / pinyin). They
/// live on the same contract because they serve the same product flow — the
/// reader's "look up this text" bottom sheet — and share the same language
/// pack lifecycle (downloaded together per language).
///
/// Consumers get both through a single DI entry (`deps.translationService`);
/// implementations can back each method with a different data source (SQLite
/// for pronunciation, on-device adapters / HTTP for translation) without
/// leaking that coupling to callers.
abstract class TranslationService {
  /// Translates [text] from [fromLang] to [toLang].
  ///
  /// [contextText] is an optional surrounding excerpt from the source document.
  /// Implementations should use it only to disambiguate [text], not translate
  /// the whole excerpt.
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  });

  /// Returns all known pronunciation variants for [word] in [lang]. Empty
  /// list if the word is missing or the language dictionary isn't installed
  /// locally — callers decide whether to prompt a download or fall back to
  /// TTS / AI.
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  });

  /// Releases any open resources (database handles, caches). Safe to call
  /// repeatedly. Intended for shutdown / hot restart in development.
  Future<void> dispose();
}

/// Stub implementation — echoes the input as "translated" and returns empty
/// pronunciation results. Used for tests of unrelated code and as a safe
/// default until real backends are wired.
class NoopTranslationService implements TranslationService {
  const NoopTranslationService();

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async => TranslationResult(
    originalText: text,
    translatedText: '[$toLang] $text',
    source: TranslationSource.platform,
  );

  @override
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  }) async => const [];

  @override
  Future<void> dispose() async {}
}
