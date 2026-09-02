import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

const contextualTranslationRequestSchemaVersion =
    'readflex.contextual_translation.request.v1';
const contextualTranslationResultSchemaVersion =
    'readflex.contextual_translation.result.v1';
const contextualTranslationMode = 'contextual_lookup';
const selectedTextTranslationMode = 'text_translation';
const autoSourceLanguageCode = 'auto';
const contextualTranslationAnchorChapterTitleMaxLength = 512;

enum ContextualTranslationStatus {
  resolved,
  ambiguous,
  needsMoreContext,
  unsupported;

  String get wireName => switch (this) {
    resolved => 'resolved',
    ambiguous => 'ambiguous',
    needsMoreContext => 'needs_more_context',
    unsupported => 'unsupported',
  };

  static ContextualTranslationStatus fromWireName(Object? value) {
    return switch (value) {
      'resolved' => resolved,
      'ambiguous' => ambiguous,
      'needs_more_context' => needsMoreContext,
      'unsupported' => unsupported,
      _ => throw FormatException(
        'Unsupported contextual translation status: $value',
      ),
    };
  }
}

enum ContextualTranslationReliability {
  verified,
  probable,
  unresolved,
  offline;

  String get wireName => name;

  static ContextualTranslationReliability fromWireName(Object? value) {
    return switch (value) {
      'verified' => verified,
      'probable' => probable,
      'unresolved' => unresolved,
      'offline' => offline,
      _ => throw FormatException(
        'Unsupported contextual translation reliability: $value',
      ),
    };
  }
}

class TranslationSelection extends Equatable {
  const TranslationSelection({
    required this.text,
    this.normalizedText,
    this.kind,
  });

  final String text;
  final String? normalizedText;
  final String? kind;

  String get effectiveText {
    final normalized = normalizedText?.trim();
    return normalized == null || normalized.isEmpty ? text : normalized;
  }

  Map<String, Object?> toJson() => {
    'text': text,
    'normalized_text': normalizedText,
    'kind': kind,
  };

  factory TranslationSelection.fromJson(Map<String, Object?> json) {
    return TranslationSelection(
      text: _string(json['text']),
      normalizedText: _nullableString(json['normalized_text']),
      kind: _nullableString(json['kind']),
    );
  }

  @override
  List<Object?> get props => [text, normalizedText, kind];
}

class TranslationContextPassage extends Equatable {
  const TranslationContextPassage({
    required this.text,
    this.markedText,
    this.normalizedMarkedText,
  });

  final String text;
  final String? markedText;
  final String? normalizedMarkedText;

  Map<String, Object?> toJson() => {
    'text': text,
    'marked_text': markedText,
    'normalized_marked_text': normalizedMarkedText,
  };

  factory TranslationContextPassage.fromJson(Map<String, Object?> json) {
    return TranslationContextPassage(
      text: _string(json['text']),
      markedText: _nullableString(json['marked_text']),
      normalizedMarkedText: _nullableString(json['normalized_marked_text']),
    );
  }

  @override
  List<Object?> get props => [text, markedText, normalizedMarkedText];
}

class TranslationTextContext extends Equatable {
  const TranslationTextContext({
    required this.level,
    this.current,
    this.previous,
    this.next,
    this.paragraph,
  });

  final String level;
  final TranslationContextPassage? current;
  final String? previous;
  final String? next;
  final String? paragraph;

  Map<String, Object?> toJson() => {
    'level': level,
    'current': current?.toJson(),
    'previous': previous,
    'next': next,
    'paragraph': paragraph,
  };

  factory TranslationTextContext.fromJson(Map<String, Object?> json) {
    return TranslationTextContext(
      level: _string(json['level'], fallback: 'sentence'),
      current: _map(json['current']) == null
          ? null
          : TranslationContextPassage.fromJson(_map(json['current'])!),
      previous: _nullableString(json['previous']),
      next: _nullableString(json['next']),
      paragraph: _nullableString(json['paragraph']),
    );
  }

  @override
  List<Object?> get props => [level, current, previous, next, paragraph];
}

class TranslationAnchor extends Equatable {
  const TranslationAnchor({
    required this.sourceId,
    required this.sourceType,
    this.cfiRange,
    this.normalizedCfiRange,
    this.progress,
    this.chapterTitle,
  });

  final String sourceId;
  final String sourceType;
  final String? cfiRange;
  final String? normalizedCfiRange;
  final double? progress;
  final String? chapterTitle;

  Map<String, Object?> toJson() => {
    'source_id': sourceId,
    'source_type': sourceType,
    'cfi_range': cfiRange,
    'normalized_cfi_range': normalizedCfiRange,
    'progress': progress,
    'chapter_title': _boundedOptionalString(
      chapterTitle,
      maxLength: contextualTranslationAnchorChapterTitleMaxLength,
    ),
  };

  factory TranslationAnchor.fromJson(Map<String, Object?> json) {
    return TranslationAnchor(
      sourceId: _string(json['source_id']),
      sourceType: _string(json['source_type']),
      cfiRange: _nullableString(json['cfi_range']),
      normalizedCfiRange: _nullableString(json['normalized_cfi_range']),
      progress: _nullableDouble(json['progress']),
      chapterTitle: _nullableString(json['chapter_title']),
    );
  }

  @override
  List<Object?> get props => [
    sourceId,
    sourceType,
    cfiRange,
    normalizedCfiRange,
    progress,
    chapterTitle,
  ];
}

class ContextualTranslationRequest extends Equatable {
  ContextualTranslationRequest({
    String? requestId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.selection,
    required this.context,
    required this.anchor,
    this.sourceLanguageHint,
    this.mode = contextualTranslationMode,
  }) : requestId = requestId ?? const Uuid().v4();

  final String requestId;
  final String sourceLanguage;
  final String? sourceLanguageHint;
  final String targetLanguage;
  final String mode;
  final TranslationSelection selection;
  final TranslationTextContext context;
  final TranslationAnchor anchor;

  String? get concreteSourceLanguage {
    final explicit = _normalizedLanguageCode(sourceLanguage);
    if (explicit != null && explicit != autoSourceLanguageCode) return explicit;
    return _normalizedLanguageCode(sourceLanguageHint);
  }

  ContextualTranslationRequest copyWith({
    String? requestId,
    String? sourceLanguage,
    String? sourceLanguageHint,
    String? targetLanguage,
    String? mode,
    TranslationSelection? selection,
    TranslationTextContext? context,
    TranslationAnchor? anchor,
  }) {
    return ContextualTranslationRequest(
      requestId: requestId ?? this.requestId,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      sourceLanguageHint: sourceLanguageHint ?? this.sourceLanguageHint,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      selection: selection ?? this.selection,
      context: context ?? this.context,
      anchor: anchor ?? this.anchor,
      mode: mode ?? this.mode,
    );
  }

  Map<String, Object?> toJson() => {
    'schema_version': contextualTranslationRequestSchemaVersion,
    'request_id': requestId,
    'source_language': sourceLanguage,
    'source_language_hint': sourceLanguageHint,
    'target_language': targetLanguage,
    'mode': mode,
    'selection': selection.toJson(),
    'context': context.toJson(),
    'anchor': anchor.toJson(),
  };

  String toCacheKey() {
    final json = toJson()..remove('request_id');
    return jsonEncode(json);
  }

  factory ContextualTranslationRequest.fromJson(Map<String, Object?> json) {
    return ContextualTranslationRequest(
      requestId: _nullableString(json['request_id']),
      sourceLanguage: _string(
        json['source_language'],
        fallback: autoSourceLanguageCode,
      ),
      sourceLanguageHint: _nullableString(json['source_language_hint']),
      targetLanguage: _string(json['target_language']),
      mode: _string(json['mode'], fallback: contextualTranslationMode),
      selection: TranslationSelection.fromJson(_map(json['selection']) ?? {}),
      context: TranslationTextContext.fromJson(_map(json['context']) ?? {}),
      anchor: TranslationAnchor.fromJson(_map(json['anchor']) ?? {}),
    );
  }

  @override
  List<Object?> get props => [
    requestId,
    sourceLanguage,
    sourceLanguageHint,
    targetLanguage,
    mode,
    selection,
    context,
    anchor,
  ];
}

class ContextualTranslationAnalysis extends Equatable {
  const ContextualTranslationAnalysis({
    this.selectedTokenIds = const [],
    this.expressionTokenIds = const [],
    this.surfaceForm,
    this.lemma,
    this.expressionType,
    this.partOfSpeech,
    this.grammaticalForm,
    this.contextualMeaningEn,
  });

  final List<int> selectedTokenIds;
  final List<int> expressionTokenIds;
  final String? surfaceForm;
  final String? lemma;
  final String? expressionType;
  final String? partOfSpeech;
  final String? grammaticalForm;
  final String? contextualMeaningEn;

  Map<String, Object?> toJson() => {
    'selected_token_ids': selectedTokenIds,
    'expression_token_ids': expressionTokenIds,
    'surface_form': surfaceForm,
    'lemma': lemma,
    'expression_type': expressionType,
    'part_of_speech': partOfSpeech,
    'grammatical_form': grammaticalForm,
    'contextual_meaning_en': contextualMeaningEn,
  };

  factory ContextualTranslationAnalysis.fromJson(Map<String, Object?> json) {
    return ContextualTranslationAnalysis(
      selectedTokenIds: _checkedIntList(json, 'selected_token_ids'),
      expressionTokenIds: _checkedIntList(json, 'expression_token_ids'),
      surfaceForm: _checkedOptionalString(json, 'surface_form'),
      lemma: _checkedOptionalString(json, 'lemma'),
      expressionType: _checkedOptionalString(json, 'expression_type'),
      partOfSpeech: _checkedOptionalString(json, 'part_of_speech'),
      grammaticalForm: _checkedOptionalString(json, 'grammatical_form'),
      contextualMeaningEn: _checkedOptionalString(
        json,
        'contextual_meaning_en',
      ),
    );
  }

  @override
  List<Object?> get props => [
    selectedTokenIds,
    expressionTokenIds,
    surfaceForm,
    lemma,
    expressionType,
    partOfSpeech,
    grammaticalForm,
    contextualMeaningEn,
  ];
}

class ContextualTranslationText extends Equatable {
  const ContextualTranslationText({
    this.baseTranslation,
    this.contextualTranslation,
    this.translatedFragment,
    this.sentenceTranslation,
  });

  final String? baseTranslation;
  final String? contextualTranslation;
  final String? translatedFragment;
  final String? sentenceTranslation;

  Map<String, Object?> toJson() => {
    'base_translation': baseTranslation,
    'contextual_translation': contextualTranslation,
    'translated_fragment': translatedFragment,
    'sentence_translation': sentenceTranslation,
  };

  factory ContextualTranslationText.fromJson(Map<String, Object?> json) {
    return ContextualTranslationText(
      baseTranslation: _checkedOptionalString(json, 'base_translation'),
      contextualTranslation: _checkedOptionalString(
        json,
        'contextual_translation',
      ),
      translatedFragment: _checkedOptionalString(json, 'translated_fragment'),
      sentenceTranslation: _checkedOptionalString(json, 'sentence_translation'),
    );
  }

  @override
  List<Object?> get props => [
    baseTranslation,
    contextualTranslation,
    translatedFragment,
    sentenceTranslation,
  ];
}

class ContextualTranslationAlternative extends Equatable {
  const ContextualTranslationAlternative({
    required this.translation,
    this.meaning,
    this.note,
  });

  final String translation;
  final String? meaning;
  final String? note;

  Map<String, Object?> toJson() => {
    'translation': translation,
    'meaning': meaning,
    'note': note,
  };

  factory ContextualTranslationAlternative.fromJson(Map<String, Object?> json) {
    return ContextualTranslationAlternative(
      translation: _requiredString(json, 'translation'),
      meaning: _checkedOptionalString(json, 'meaning'),
      note: _checkedOptionalString(json, 'note'),
    );
  }

  @override
  List<Object?> get props => [translation, meaning, note];
}

class ContextualTranslationSource extends Equatable {
  const ContextualTranslationSource({
    this.provider,
    this.modelId,
    this.promptVersion,
    this.schemaVersion,
  });

  final String? provider;
  final String? modelId;
  final String? promptVersion;
  final String? schemaVersion;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'model_id': modelId,
    'prompt_version': promptVersion,
    'schema_version': schemaVersion,
  };

  factory ContextualTranslationSource.fromJson(Map<String, Object?> json) {
    return ContextualTranslationSource(
      provider: _checkedOptionalString(json, 'provider'),
      modelId: _checkedOptionalString(json, 'model_id'),
      promptVersion: _checkedOptionalString(json, 'prompt_version'),
      schemaVersion: _checkedOptionalString(json, 'schema_version'),
    );
  }

  @override
  List<Object?> get props => [provider, modelId, promptVersion, schemaVersion];
}

class ContextualTranslationResult extends Equatable {
  const ContextualTranslationResult({
    required this.requestId,
    required this.status,
    required this.reliability,
    required this.translation,
    this.mode = contextualTranslationMode,
    this.provider,
    this.detectedSourceLanguage,
    this.targetLanguage,
    this.analysis,
    this.explanation,
    this.alternatives = const [],
    this.source = const ContextualTranslationSource(),
  });

  final String requestId;
  final String mode;
  final String? provider;
  final ContextualTranslationStatus status;
  final ContextualTranslationReliability reliability;
  final String? detectedSourceLanguage;
  final String? targetLanguage;
  final ContextualTranslationAnalysis? analysis;
  final ContextualTranslationText translation;
  final String? explanation;
  final List<ContextualTranslationAlternative> alternatives;
  final ContextualTranslationSource source;

  Map<String, Object?> toJson() => {
    'schema_version': contextualTranslationResultSchemaVersion,
    'request_id': requestId,
    'mode': mode,
    'provider': provider,
    'status': status.wireName,
    'reliability': reliability.wireName,
    'detected_source_language': detectedSourceLanguage,
    'target_language': targetLanguage,
    'analysis': analysis?.toJson(),
    'translation': translation.toJson(),
    'explanation': explanation,
    'alternatives': alternatives.map((item) => item.toJson()).toList(),
    'source': source.toJson(),
  };

  factory ContextualTranslationResult.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredString(json, 'schema_version');
    if (schemaVersion != contextualTranslationResultSchemaVersion) {
      throw FormatException(
        'Unsupported contextual translation result schema: $schemaVersion',
      );
    }

    final mode = _requiredString(json, 'mode');
    if (mode != contextualTranslationMode &&
        mode != selectedTextTranslationMode) {
      throw FormatException('Unsupported contextual translation mode: $mode');
    }

    final status = ContextualTranslationStatus.fromWireName(json['status']);
    final translation = ContextualTranslationText.fromJson(
      _requiredMap(json, 'translation'),
    );
    if ((status == ContextualTranslationStatus.resolved ||
            status == ContextualTranslationStatus.ambiguous) &&
        !_hasTranslationText(translation)) {
      throw const FormatException(
        'Resolved contextual translation must contain translated text',
      );
    }
    final analysis = _optionalMap(json, 'analysis');

    return ContextualTranslationResult(
      requestId: _requiredString(json, 'request_id'),
      mode: mode,
      provider: _checkedOptionalString(json, 'provider'),
      status: status,
      reliability: ContextualTranslationReliability.fromWireName(
        json['reliability'],
      ),
      detectedSourceLanguage: _checkedOptionalString(
        json,
        'detected_source_language',
      ),
      targetLanguage: _checkedOptionalString(json, 'target_language'),
      analysis: analysis == null
          ? null
          : ContextualTranslationAnalysis.fromJson(analysis),
      translation: translation,
      explanation: _checkedOptionalString(json, 'explanation'),
      alternatives: _checkedObjectList(
        json,
        'alternatives',
      ).map(ContextualTranslationAlternative.fromJson).toList(growable: false),
      source: ContextualTranslationSource.fromJson(
        _requiredMap(json, 'source'),
      ),
    );
  }

  factory ContextualTranslationResult.offline({
    required ContextualTranslationRequest request,
    required String sourceLanguage,
    required String selectedTranslation,
    String? sentenceTranslation,
  }) {
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      provider: 'google_mlkit_translation',
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.offline,
      detectedSourceLanguage: sourceLanguage,
      targetLanguage: request.targetLanguage,
      translation: ContextualTranslationText(
        contextualTranslation: selectedTranslation,
        translatedFragment: selectedTranslation,
        sentenceTranslation: sentenceTranslation,
      ),
      source: const ContextualTranslationSource(
        provider: 'google_mlkit_translation',
        schemaVersion: contextualTranslationResultSchemaVersion,
      ),
    );
  }

  @override
  List<Object?> get props => [
    requestId,
    mode,
    provider,
    status,
    reliability,
    detectedSourceLanguage,
    targetLanguage,
    analysis,
    translation,
    explanation,
    alternatives,
    source,
  ];
}

String _string(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  return fallback;
}

String? _nullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _boundedOptionalString(String? value, {required int maxLength}) {
  final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.length > maxLength) {
    return null;
  }
  return normalized;
}

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

Map<String, Object?>? _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return null;
}

String? _normalizedLanguageCode(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.split(RegExp(r'[-_]')).first;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _checkedOptionalString(json, key);
  if (value == null) throw FormatException('$key must be a non-empty string');
  return value;
}

String? _checkedOptionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string');
  return _nullableString(value);
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = _optionalMap(json, key);
  if (value == null) throw FormatException('$key must be an object');
  return value;
}

Map<String, Object?>? _optionalMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('$key must be an object');
  try {
    return Map<String, Object?>.from(value);
  } on TypeError catch (error) {
    throw FormatException('$key must have string keys', error);
  }
}

List<Map<String, Object?>> _checkedObjectList(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('$key must be a list');
  return [
    for (var index = 0; index < value.length; index++)
      if (value[index] is Map)
        Map<String, Object?>.from(value[index] as Map)
      else
        throw FormatException('$key[$index] must be an object'),
  ];
}

List<int> _checkedIntList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('$key must be a list');
  return [
    for (var index = 0; index < value.length; index++)
      if (value[index] case final int item)
        item
      else
        throw FormatException('$key[$index] must be an integer'),
  ];
}

bool _hasTranslationText(ContextualTranslationText translation) {
  return [
    translation.baseTranslation,
    translation.contextualTranslation,
    translation.translatedFragment,
    translation.sentenceTranslation,
  ].any((value) => value != null && value.isNotEmpty);
}
