part of 'translate_cubit.dart';

/// Lifecycle of the translate sheet: translation in flight, translation
/// ready, dictionary save in flight, done, or error.
enum TranslateStatus { idle, translating, translated, saving, saved, failure }

/// State of the translate sheet: the translation result (text, source,
/// usage examples) plus the current status and optional error message.
class TranslateState extends Equatable {
  const TranslateState({
    this.status = TranslateStatus.idle,
    this.translatedText = '',
    this.source = TranslationSource.platform,
    this.usageExamples = const [],
    this.errorMessage,
  });

  final TranslateStatus status;
  final String translatedText;
  final TranslationSource source;
  final List<String> usageExamples;
  final String? errorMessage;

  TranslateState copyWith({
    TranslateStatus? status,
    String? translatedText,
    TranslationSource? source,
    List<String>? usageExamples,
    String? errorMessage,
  }) => TranslateState(
    status: status ?? this.status,
    translatedText: translatedText ?? this.translatedText,
    source: source ?? this.source,
    usageExamples: usageExamples ?? this.usageExamples,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    translatedText,
    source,
    usageExamples,
    errorMessage,
  ];
}
