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

  _sameLanguageTests();

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
    await pumpEventQueue();
    expect(service.cancelled, [0]);
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
    expect(service.cancelled, [0]);
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

void _sameLanguageTests() {
  group('same language', () {
    late PreferencesService preferences;

    setUp(() async {
      preferences = await PreferencesService.create(
        supportedCodes: const ['en', 'ru', 'de'],
      );
      await preferences.update(
        (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
      );
    });
    tearDown(() => preferences.dispose());

    TranslateCubit createCubit(ContextualTranslationService service) {
      final cubit = TranslateCubit(
        translationService: service,
        preferencesService: preferences,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('a target equal to the detected language sends no request', () async {
      final service = _FakeTranslationService();
      final cubit = createCubit(service);
      await cubit.translate(_selection());
      expect(cubit.state.detectedSourceLanguage, 'en');
      expect(service.calls, 1);

      await cubit.setTargetLanguage(_selection(), 'en-US');

      expect(cubit.state.status, TranslateSheetStatus.sameLanguage);
      expect(cubit.state.targetLanguageCode, 'en-US');
      expect(cubit.state.result, isNull);
      expect(cubit.state.detectedSourceLanguage, 'en');
      expect(service.calls, 1);
      expect(
        preferences.current.translationTargetLanguageCode,
        'en-US',
        reason: 'the choice is still kept as the default target',
      );
    });

    test('another target after that translates again', () async {
      final service = _FakeTranslationService();
      final cubit = createCubit(service);
      await cubit.translate(_selection());
      await cubit.setTargetLanguage(_selection(), 'en');

      await cubit.setTargetLanguage(_selection(), 'de');

      expect(cubit.state.status, TranslateSheetStatus.success);
      expect(service.calls, 2);
      expect(service.lastRequest?.targetLanguage, 'de');
    });

    test('a chosen source equal to the target sends no request', () async {
      final service = _FakeTranslationService();
      final cubit = createCubit(service);
      await cubit.translate(_selection());

      await cubit.setSourceLanguage(_selection(), 'ru');

      expect(cubit.state.status, TranslateSheetStatus.sameLanguage);
      expect(cubit.state.sourceLanguageCode, 'ru');
      expect(service.calls, 1);
    });

    test(
      'back to automatic with a detected language equal to the target',
      () async {
        final service = _FakeTranslationService();
        final cubit = createCubit(service);
        await cubit.translate(_selection());
        await cubit.setSourceLanguage(_selection(), 'de');
        expect(service.calls, 2);
        await cubit.setTargetLanguage(_selection(), 'en');
        expect(service.calls, 3, reason: 'de to en is a real translation');

        await cubit.setSourceLanguage(_selection(), autoSourceLanguageCode);

        expect(cubit.state.status, TranslateSheetStatus.sameLanguage);
        expect(service.calls, 3);
      },
    );

    test(
      'a same-language answer shows the state and keeps its language',
      () async {
        final service = _FakeTranslationService(
          error: const ContextualTranslationException(
            ContextualTranslationFailureReason.sameLanguage,
            'same',
            sourceLanguage: 'ru',
            targetLanguage: 'ru',
          ),
        );
        final cubit = createCubit(service);

        await cubit.translate(_selection());

        expect(cubit.state.status, TranslateSheetStatus.sameLanguage);
        expect(cubit.state.detectedSourceLanguage, 'ru');
        expect(cubit.state.isBusy, isFalse);
      },
    );

    test(
      'a same-language answer to a chosen source keeps the detection',
      () async {
        final service = _FakeTranslationService();
        final cubit = createCubit(service);
        await cubit.translate(_selection());
        service.error = const ContextualTranslationException(
          ContextualTranslationFailureReason.sameLanguage,
          'same',
          sourceLanguage: 'de',
          targetLanguage: 'ru',
        );

        await cubit.setSourceLanguage(_selection(), 'de');

        expect(cubit.state.status, TranslateSheetStatus.sameLanguage);
        expect(cubit.state.detectedSourceLanguage, 'en');
      },
    );

    test('a same-language target cancels a running request', () async {
      final service = _ControlledTranslationService();
      final cubit = createCubit(service);
      final first = cubit.translate(_selection());
      service.complete(0, translation: 'бросил');
      await first;

      final pending = cubit.setTargetLanguage(_selection(), 'de');
      await pumpEventQueue();
      expect(service.requests, hasLength(2));
      // Starting the second request also aborts the finished first one,
      // which is a no-op.
      expect(service.cancelled, [0]);

      await cubit.setTargetLanguage(_selection(), 'en');
      await pumpEventQueue();
      expect(service.cancelled, [0, 1]);
      expect(cubit.state.status, TranslateSheetStatus.sameLanguage);

      service.complete(1, translation: 'late');
      await pending;
      expect(cubit.state.status, TranslateSheetStatus.sameLanguage);
      expect(cubit.state.result, isNull);
    });
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

  ContextualTranslationException? error;
  ContextualTranslationRequest? lastRequest;
  var calls = 0;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    calls++;
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
  final cancelled = <int>[];
  final _responses = <Completer<ContextualTranslationResult>>[];

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) {
    final index = requests.length;
    abortTrigger?.then((_) => cancelled.add(index));
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
