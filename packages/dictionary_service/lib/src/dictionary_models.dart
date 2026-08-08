import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum DictionaryLookupStatus {
  found('found'),
  notFound('not_found'),
  unsupportedLanguage('unsupported_language');

  const DictionaryLookupStatus(this.wireValue);

  final String wireValue;

  static DictionaryLookupStatus fromWireValue(String value) {
    return values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () =>
          throw FormatException('Unsupported dictionary lookup status: $value'),
    );
  }
}

class DictionaryLookupRequest extends Equatable {
  DictionaryLookupRequest({
    required this.term,
    String? requestId,
    this.sourceLanguage,
    this.contextText,
  }) : requestId = requestId ?? const Uuid().v4();

  final String requestId;
  final String term;
  final String? sourceLanguage;
  final String? contextText;

  Map<String, Object?> toJson() => {
    'request_id': requestId,
    'term': term,
    'source_language': ?_normalizedOptional(sourceLanguage),
    'context_text': ?_normalizedOptional(contextText),
  };

  @override
  List<Object?> get props => [requestId, term, sourceLanguage, contextText];
}

class DictionaryLookupResult extends Equatable {
  const DictionaryLookupResult({
    required this.requestId,
    required this.status,
    required this.term,
    this.language,
    this.entries = const [],
  });

  factory DictionaryLookupResult.fromJson(Map<String, Object?> json) {
    final status = _requiredString(json, 'status');
    final rawEntries = json['entries'];
    if (rawEntries != null && rawEntries is! List) {
      throw const FormatException('entries must be a list');
    }
    final entries = rawEntries == null ? const <Object?>[] : rawEntries as List;
    return DictionaryLookupResult(
      requestId: _requiredString(json, 'request_id'),
      status: DictionaryLookupStatus.fromWireValue(status),
      term: _requiredString(json, 'term'),
      language: _optionalString(json['language']),
      entries: [
        for (final entry in entries)
          DictionaryLexicalEntry.fromJson(_objectMap(entry, 'entry')),
      ],
    );
  }

  final String requestId;
  final DictionaryLookupStatus status;
  final String term;
  final String? language;
  final List<DictionaryLexicalEntry> entries;

  @override
  List<Object?> get props => [requestId, status, term, language, entries];
}

class DictionaryLexicalEntry extends Equatable {
  const DictionaryLexicalEntry({
    required this.lemma,
    required this.definitions,
    this.language,
    this.reading,
    this.pronunciation,
    this.partOfSpeech,
  });

  factory DictionaryLexicalEntry.fromJson(Map<String, Object?> json) {
    final rawDefinitions = json['definitions'];
    if (rawDefinitions is! List) {
      throw const FormatException('definitions must be a list');
    }
    return DictionaryLexicalEntry(
      lemma: _requiredString(json, 'lemma'),
      language: _optionalString(json['language']),
      reading: _optionalString(json['reading']),
      pronunciation: _optionalString(json['pronunciation']),
      partOfSpeech: _optionalString(json['part_of_speech']),
      definitions: [
        for (final definition in rawDefinitions)
          DictionaryDefinition.fromJson(_objectMap(definition, 'definition')),
      ],
    );
  }

  final String lemma;
  final String? language;
  final String? reading;
  final String? pronunciation;
  final String? partOfSpeech;
  final List<DictionaryDefinition> definitions;

  @override
  List<Object?> get props => [
    lemma,
    language,
    reading,
    pronunciation,
    partOfSpeech,
    definitions,
  ];
}

class DictionaryDefinition extends Equatable {
  const DictionaryDefinition({required this.text, this.examples = const []});

  factory DictionaryDefinition.fromJson(Map<String, Object?> json) {
    final rawExamples = json['examples'];
    if (rawExamples != null && rawExamples is! List) {
      throw const FormatException('examples must be a list');
    }
    final examples = rawExamples == null
        ? const <Object?>[]
        : rawExamples as List;
    return DictionaryDefinition(
      text: _requiredString(json, 'text'),
      examples: [for (final example in examples) ?_optionalString(example)],
    );
  }

  final String text;
  final List<String> examples;

  @override
  List<Object?> get props => [text, examples];
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) throw FormatException('$key must be a non-empty string');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  return _normalizedOptional(value);
}

String? _normalizedOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Map<String, Object?> _objectMap(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object');
  return Map<String, Object?>.from(value);
}
