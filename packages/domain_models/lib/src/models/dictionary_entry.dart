import 'package:equatable/equatable.dart' show Equatable;

import 'source_type.dart';

/// A saved word or phrase in the user's dictionary.
class DictionaryEntry extends Equatable {
  const DictionaryEntry({
    required this.id,
    required this.word,
    required this.translation,
    required this.addedAt,
    this.pronunciation,
    this.partOfSpeech,
    this.context,
    this.sourceId,
    this.sourceType,
    this.usageExamples = const [],
    this.lemma,
    this.baseTranslation,
    this.contextTranslation,
  });

  final String id;

  /// The form the reader selected.
  final String word;

  /// The meaning in the saved [context].
  final String translation;

  /// Dictionary form when it differs from [word].
  final String? lemma;

  /// The word's own meaning, when it differs from [translation].
  final String? baseTranslation;

  /// Translation of [context].
  final String? contextTranslation;
  final String? pronunciation;
  final String? partOfSpeech;
  final String? context;
  final String? sourceId;
  final SourceType? sourceType;
  final List<String> usageExamples;
  final DateTime addedAt;

  static const _absent = Object();

  DictionaryEntry copyWith({
    String? word,
    String? translation,
    Object? pronunciation = _absent,
    Object? partOfSpeech = _absent,
    Object? context = _absent,
    Object? sourceId = _absent,
    Object? sourceType = _absent,
    List<String>? usageExamples,
    Object? lemma = _absent,
    Object? baseTranslation = _absent,
    Object? contextTranslation = _absent,
  }) => DictionaryEntry(
    id: id,
    word: word ?? this.word,
    translation: translation ?? this.translation,
    pronunciation: pronunciation == _absent
        ? this.pronunciation
        : pronunciation as String?,
    partOfSpeech: partOfSpeech == _absent
        ? this.partOfSpeech
        : partOfSpeech as String?,
    context: context == _absent ? this.context : context as String?,
    sourceId: sourceId == _absent ? this.sourceId : sourceId as String?,
    sourceType: sourceType == _absent
        ? this.sourceType
        : sourceType as SourceType?,
    usageExamples: usageExamples ?? this.usageExamples,
    lemma: lemma == _absent ? this.lemma : lemma as String?,
    baseTranslation: baseTranslation == _absent
        ? this.baseTranslation
        : baseTranslation as String?,
    contextTranslation: contextTranslation == _absent
        ? this.contextTranslation
        : contextTranslation as String?,
    addedAt: addedAt,
  );

  @override
  List<Object?> get props => [
    id,
    word,
    translation,
    pronunciation,
    partOfSpeech,
    context,
    sourceId,
    sourceType,
    usageExamples,
    lemma,
    baseTranslation,
    contextTranslation,
    addedAt,
  ];
}
