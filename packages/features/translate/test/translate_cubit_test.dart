import 'dart:async';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('translate builds contextual request from text selection', () async {
    final service = _FakeTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    await preferences.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );

    await cubit.translate(_selection());

    expect(cubit.state.status, TranslateSheetStatus.success);
    expect(service.lastRequest?.sourceLanguage, autoSourceLanguageCode);
    expect(service.lastRequest?.sourceLanguageHint, 'en');
    expect(service.lastRequest?.targetLanguage, 'ru');
    expect(service.lastRequest?.mode, contextualTranslationMode);
    expect(service.lastRequest?.selection.effectiveText, 'gave up');
    expect(
      service.lastRequest?.context.current?.markedText,
      contains('[[up]]'),
    );
  });

  test('uses text translation mode for a paragraph selection', () async {
    final service = _FakeTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );
    const paragraph =
        'Launches are mostly arbitrary these days. '
        'With continuous development, you launch every few hours.';
    const selection = TextSelectionContext(
      selectedText: paragraph,
      selectionKind: 'exact',
      contextText: paragraph,
      markedContextText:
          '[[Launches are mostly arbitrary these days. '
          'With continuous development, you launch every few hours.]]',
      sourceId: 'source-1',
      sourceType: SourceType.article,
      sourceLanguageHint: 'en',
    );

    await cubit.translate(selection);

    expect(service.lastRequest?.mode, selectedTextTranslationMode);
    expect(service.lastRequest?.selection.effectiveText, paragraph);
    expect(service.lastRequest?.context.level, 'selection');
  });

  test('uses text translation mode for a selected whole sentence', () async {
    final service = _FakeTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );
    const sentence = 'Continuous delivery changes release planning';
    const selection = TextSelectionContext(
      selectedText: sentence,
      selectionKind: 'exact',
      contextText: sentence,
      sourceId: 'source-1',
      sourceType: SourceType.article,
    );

    await cubit.translate(selection);

    expect(service.lastRequest?.mode, selectedTextTranslationMode);
  });

  test('setTargetLanguage persists preference and retranslates', () async {
    final service = _FakeTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );

    await cubit.setTargetLanguage(_selection(), 'ru');

    expect(preferences.current.translationTargetLanguageCode, 'ru');
    expect(service.lastRequest?.targetLanguage, 'ru');
  });

  test('ignores stale single-word normalization after range resize', () async {
    final service = _FakeTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );
    const selection = TextSelectionContext(
      selectedText: 'power bank is light',
      normalizedSelectedText: 'power',
      selectionKind: 'partial_word',
      contextText: 'This power bank is light enough for travel.',
      markedContextText: 'This [[power bank is light]] enough for travel.',
      normalizedMarkedContextText:
          'This [[power]] bank is light enough for travel.',
      sourceId: 'source-1',
      sourceType: SourceType.article,
    );

    await cubit.translate(selection);

    expect(service.lastRequest?.selection.text, 'power bank is light');
    expect(service.lastRequest?.selection.normalizedText, isNull);
    expect(service.lastRequest?.selection.effectiveText, 'power bank is light');
    expect(service.lastRequest?.context.current?.normalizedMarkedText, isNull);
  });

  test('maps offline model requirement to sheet state', () async {
    final service = _FakeTranslationService(
      error: const ContextualTranslationException(
        ContextualTranslationFailureReason.offlineModelRequired,
        'download',
        sourceLanguage: 'en',
        targetLanguage: 'ru',
      ),
    );
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    await preferences.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );

    await cubit.translate(_selection());

    expect(cubit.state.status, TranslateSheetStatus.offlineModelRequired);
    expect(cubit.state.failure?.sourceLanguage, 'en');
  });

  test('ignores a translation result delivered after close', () async {
    final service = _ControlledTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );

    final translation = cubit.translate(_selection());
    expect(service.requests, hasLength(1));
    expect(cubit.state.status, TranslateSheetStatus.loading);

    await cubit.close();
    service.complete(0, translation: 'late');

    await expectLater(translation, completes);
    expect(cubit.state.status, TranslateSheetStatus.loading);
  });

  test('a stale translation cannot replace a newer language result', () async {
    final service = _ControlledTranslationService();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru'],
    );
    final cubit = TranslateCubit(
      translationService: service,
      preferencesService: preferences,
    );

    final firstTranslation = cubit.translate(_selection());
    final secondTranslation = cubit.setTargetLanguage(_selection(), 'ru');
    await pumpEventQueue();

    expect(service.requests, hasLength(2));
    expect(service.requests[0].targetLanguage, 'en');
    expect(service.requests[1].targetLanguage, 'ru');

    service.complete(1, translation: 'new');
    await secondTranslation;
    service.complete(0, translation: 'stale');
    await firstTranslation;

    expect(cubit.state.status, TranslateSheetStatus.success);
    expect(cubit.state.targetLanguageCode, 'ru');
    expect(cubit.state.result?.translation.contextualTranslation, 'new');
  });
}

TextSelectionContext _selection() {
  return const TextSelectionContext(
    selectedText: 'up',
    normalizedSelectedText: 'gave up',
    selectionKind: 'partial_word',
    contextText: 'He finally gave up smoking.',
    markedContextText: 'He finally gave [[up]] smoking.',
    normalizedMarkedContextText: 'He finally [[gave up]] smoking.',
    sourceId: 'source-1',
    sourceType: SourceType.book,
    cfiRange: 'epubcfi(/6/8)',
    progress: 0.5,
    chapterTitle: 'Chapter',
    sourceLanguageHint: 'en',
  );
}

class _FakeTranslationService implements ContextualTranslationService {
  _FakeTranslationService({this.error});

  final ContextualTranslationException? error;
  ContextualTranslationRequest? lastRequest;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    lastRequest = request;
    final error = this.error;
    if (error != null) throw error;
    return ContextualTranslationResult(
      requestId: request.requestId,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      translation: const ContextualTranslationText(
        contextualTranslation: 'бросил',
      ),
    );
  }

  @override
  void dispose() {}
}

class _ControlledTranslationService implements ContextualTranslationService {
  final requests = <ContextualTranslationRequest>[];
  final _responses = <Completer<ContextualTranslationResult>>[];

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) {
    requests.add(request);
    final response = Completer<ContextualTranslationResult>();
    _responses.add(response);
    return response.future;
  }

  void complete(int index, {required String translation}) {
    final request = requests[index];
    _responses[index].complete(
      ContextualTranslationResult(
        requestId: request.requestId,
        status: ContextualTranslationStatus.resolved,
        reliability: ContextualTranslationReliability.verified,
        detectedSourceLanguage: 'en',
        targetLanguage: request.targetLanguage,
        translation: ContextualTranslationText(
          contextualTranslation: translation,
        ),
      ),
    );
  }

  @override
  void dispose() {}
}
