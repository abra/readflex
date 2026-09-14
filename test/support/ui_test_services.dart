import 'dart:async';

import 'package:article_extraction_service/article_extraction_service.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';

import 'reading_fixture.dart';

class FixtureArticleExtraction implements ArticleExtractionService {
  final requests = <String>[];
  bool fail = false;

  @override
  Future<ExtractedArticle> extract(String url) async {
    requests.add(url);
    if (fail) throw const ArticleExtractionException('Fixture unavailable');
    if (url != ReadingFixture.articleUrl) {
      throw StateError('Unexpected article request: $url');
    }
    return ReadingFixture.article;
  }

  @override
  void dispose() {}
}

class FixtureTranslation implements ContextualTranslationService {
  FixtureTranslation({
    this.includeLexicalDetails = false,
    this.primaryTranslation,
    this.baseTranslation,
  });

  static const translatedText = 'Ein tragbarer Akku versorgt die Geraete.';
  bool includeLexicalDetails;
  final String? primaryTranslation;
  final String? baseTranslation;
  final requests = <ContextualTranslationRequest>[];
  ContextualTranslationFailureReason? failure;
  Completer<void>? pending;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    requests.add(request);
    await pending?.future;
    if (failure case final reason?) {
      throw ContextualTranslationException(reason, 'Fixture failure');
    }
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      translation: ContextualTranslationText(
        baseTranslation: baseTranslation,
        contextualTranslation:
            primaryTranslation ??
            (includeLexicalDetails ? 'Externer Akku' : translatedText),
        sentenceTranslation: 'Der Akku versorgt die Geraete mit Strom.',
      ),
      analysis: includeLexicalDetails
          ? const ContextualTranslationAnalysis(lemma: 'power bank')
          : null,
      explanation: includeLexicalDetails
          ? 'Ein tragbarer Akku zum Laden mobiler Geraete.'
          : null,
      alternatives: includeLexicalDetails
          ? const [
              ContextualTranslationAlternative(translation: 'Zusatzakku'),
              ContextualTranslationAlternative(translation: 'Ersatzakku'),
            ]
          : const [],
    );
  }

  @override
  void dispose() {}
}

class FixtureDictionary implements DictionaryLookupService {
  FixtureDictionary({
    this.entries = const [
      DictionaryLexicalEntry(
        lemma: 'power',
        partOfSpeech: 'noun',
        definitions: [
          DictionaryDefinition(
            text: 'Energy used to operate a device.',
            examples: ['The device needs power.'],
          ),
        ],
      ),
    ],
  });

  final requests = <DictionaryLookupRequest>[];
  bool unavailable = false;
  List<DictionaryLexicalEntry> entries;

  @override
  Future<DictionaryLookupResult> lookup(DictionaryLookupRequest request) async {
    requests.add(request);
    return DictionaryLookupResult(
      requestId: request.requestId,
      status: unavailable
          ? DictionaryLookupStatus.notFound
          : DictionaryLookupStatus.found,
      term: request.term,
      language: 'en',
      entries: unavailable ? const [] : entries,
    );
  }

  @override
  void dispose() {}
}

class FixtureSystemDictionary implements SystemDictionaryService {
  final requests = <String>[];
  bool available = false;

  @override
  Future<bool> showDefinition(String term) async {
    requests.add(term);
    // Native dictionary availability varies with installed OS dictionaries.
    return available;
  }
}

class FixtureConnectivity implements ConnectivityService {
  final _changes = StreamController<ConnectivityStatus>.broadcast();
  @override
  ConnectivityStatus status = ConnectivityStatus.online;

  @override
  Stream<ConnectivityStatus> get statusStream => _changes.stream;

  void setStatus(ConnectivityStatus value) {
    if (status == value) return;
    status = value;
    _changes.add(value);
  }

  @override
  Future<void> refresh() async {}

  @override
  void dispose() => unawaited(_changes.close());
}
