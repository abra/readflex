import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import '../support/ui_test_services.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('word and contextual translation ${profile.name}', (
      tester,
    ) async {
      final previousPlatform = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(
        () => SharedPreferencesAsyncPlatform.instance = previousPlatform,
      );
      final preferences = await PreferencesService.create(
        supportedCodes: ['en', 'de', 'ar'],
      );
      addTearDown(preferences.dispose);
      await preferences.update(
        (p) => p.copyWith(translationTargetLanguageCode: 'de'),
      );
      final service = FixtureTranslation(
        baseTranslation: 'Kraft',
        primaryTranslation: 'Strom',
      );
      late BuildContext sheetContext;
      await pumpGoldenSurface(tester, profile, (context) {
        sheetContext = context;
        return const Scaffold();
      });
      showTranslateSheet(
        sheetContext,
        selection: const TextSelectionContext(
          selectedText: 'power',
          contextText: 'The battery supplies power to the devices.',
          markedContextText: 'The battery supplies [[power]] to the devices.',
          sourceId: 'fixture',
          sourceType: SourceType.book,
          sourceLanguageHint: 'en',
        ),
        translationService: service,
        preferencesService: preferences,
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'translation-word-context');
      final contextAnswer = find.byKey(
        const ValueKey('translation-contextual-result'),
      );
      await tester.ensureVisible(contextAnswer);
      expect(contextAnswer.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('translation-contextual-copy')).hitTestable(),
        findsOneWidget,
      );
      expect(service.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    }, tags: ['golden']);
  }
}
