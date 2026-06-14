part of 'translate_cubit.dart';

/// Lifecycle of the translate sheet: translation in flight, translation
/// ready, dictionary save in flight, done, or error.
enum TranslateStatus { idle, translating, translated, saving, saved, failure }

/// State of the translate sheet: the translation result (text, source,
/// usage examples, and analogues) plus status and optional error text.
class TranslateState extends Equatable {
  const TranslateState({
    this.status = TranslateStatus.idle,
    this.translatedText = '',
    this.source = TranslationSource.platform,
    this.answerType = TranslationAnswerType.unknown,
    this.confidence = TranslationConfidence.unknown,
    this.sense,
    this.expression,
    this.context,
    this.selectionContextText,
    this.usageExamples = const [],
    this.naturalEquivalents = const [],
    this.literalTranslation,
    this.suggestedFullPhrase,
    this.notes,
    this.savingEntryKey,
    this.savedEntryIds = const {},
    this.errorMessage,
  });

  final TranslateStatus status;
  final String translatedText;
  final TranslationSource source;
  final TranslationAnswerType answerType;
  final TranslationConfidence confidence;
  final TranslationSense? sense;
  final TranslationExpression? expression;
  final String? context;
  final String? selectionContextText;
  final List<String> usageExamples;
  final List<String> naturalEquivalents;
  final String? literalTranslation;
  final TranslationTextPair? suggestedFullPhrase;
  final TranslationTextPair? notes;
  final String? savingEntryKey;
  final Map<String, String> savedEntryIds;
  final String? errorMessage;

  static const _absent = Object();

  TranslateState copyWith({
    TranslateStatus? status,
    String? translatedText,
    TranslationSource? source,
    TranslationAnswerType? answerType,
    TranslationConfidence? confidence,
    Object? sense = _absent,
    Object? expression = _absent,
    Object? context = _absent,
    Object? selectionContextText = _absent,
    List<String>? usageExamples,
    List<String>? naturalEquivalents,
    Object? literalTranslation = _absent,
    Object? suggestedFullPhrase = _absent,
    Object? notes = _absent,
    Object? savingEntryKey = _absent,
    Map<String, String>? savedEntryIds,
    String? errorMessage,
  }) => TranslateState(
    status: status ?? this.status,
    translatedText: translatedText ?? this.translatedText,
    source: source ?? this.source,
    answerType: answerType ?? this.answerType,
    confidence: confidence ?? this.confidence,
    sense: sense == _absent ? this.sense : sense as TranslationSense?,
    expression: expression == _absent
        ? this.expression
        : expression as TranslationExpression?,
    context: context == _absent ? this.context : context as String?,
    selectionContextText: selectionContextText == _absent
        ? this.selectionContextText
        : selectionContextText as String?,
    usageExamples: usageExamples ?? this.usageExamples,
    naturalEquivalents: naturalEquivalents ?? this.naturalEquivalents,
    literalTranslation: literalTranslation == _absent
        ? this.literalTranslation
        : literalTranslation as String?,
    suggestedFullPhrase: suggestedFullPhrase == _absent
        ? this.suggestedFullPhrase
        : suggestedFullPhrase as TranslationTextPair?,
    notes: notes == _absent ? this.notes : notes as TranslationTextPair?,
    savingEntryKey: savingEntryKey == _absent
        ? this.savingEntryKey
        : savingEntryKey as String?,
    savedEntryIds: savedEntryIds ?? this.savedEntryIds,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    translatedText,
    source,
    answerType,
    confidence,
    sense,
    expression,
    context,
    selectionContextText,
    usageExamples,
    naturalEquivalents,
    literalTranslation,
    suggestedFullPhrase,
    notes,
    savingEntryKey,
    savedEntryIds,
    errorMessage,
  ];
}
