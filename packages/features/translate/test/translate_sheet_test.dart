import 'package:component_library/component_library.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'renders compact language selectors without visible From and To labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final preferences = await PreferencesService.create(
        supportedCodes: const ['en', 'ru'],
      );
      await preferences.update(
        (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
      );

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          theme: AppTheme.light(),
          home: Scaffold(
            body: TranslateSheet(
              selection: _selection,
              translationService: _FakeTranslationService(),
              preferencesService: preferences,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From'), findsNothing);
      expect(find.text('To'), findsNothing);
      expect(find.bySemanticsLabel('From'), findsOneWidget);
      expect(find.bySemanticsLabel('To'), findsOneWidget);

      final selectors = find.byType(DropdownButtonFormField<String>);
      expect(selectors, findsNWidgets(2));
      for (final selector in selectors.evaluate()) {
        expect(
          tester.getSize(find.byWidget(selector.widget)).height,
          AppSizes.buttonHeight,
        );
      }
      semantics.dispose();
    },
  );
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  normalizedSelectedText: 'power',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class _FakeTranslationService implements ContextualTranslationService {
  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    return ContextualTranslationResult(
      requestId: request.requestId,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      translation: const ContextualTranslationText(
        contextualTranslation: 'сила',
      ),
    );
  }

  @override
  void dispose() {}
}
