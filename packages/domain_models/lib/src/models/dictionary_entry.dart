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
  });

  final String id;
  final String word;
  final String translation;
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
    addedAt,
  ];
}
