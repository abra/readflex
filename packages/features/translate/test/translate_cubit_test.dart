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
    expect(service.lastRequest?.selection.effectiveText, 'gave up');
    expect(
      service.lastRequest?.context.current?.markedText,
      contains('[[up]]'),
    );
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
