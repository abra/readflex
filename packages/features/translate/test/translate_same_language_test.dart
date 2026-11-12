import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoListTile, CupertinoPopupSurface;
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:translate/translate.dart';

import '../../../component_library/test_support/platform_test_app.dart';

/// Translating text that is already in the target language: no request, a
/// clear message, and the definition for a word.
void main() {
  late PreferencesService preferences;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    await preferences.update(
      (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
    );
  });
  tearDown(() => preferences.dispose());

  final message = find.byKey(const ValueKey('translation-same-language'));
  final targetMenu = find.byKey(const ValueKey('translation-target-language'));

  ReadflexLocalizations l10nOf(WidgetTester tester) =>
      ReadflexLocalizations.of(tester.element(find.byType(TranslateSheet)))!;

  Widget app(Widget home) => MaterialApp(
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: readflexLocalizationsDelegates,
    theme: AppTheme.light(),
    home: home,
  );

  Future<void> pumpSheet(
    WidgetTester tester,
    _RecordingService service, {
    TextSelectionContext selection = _word,
    bool canDefine = true,
    bool cupertino = false,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    final sheet = TranslateSheet(
      selection: selection,
      translationService: service,
      preferencesService: preferences,
      canDefine: canDefine,
    );
    await tester.pumpWidget(
      cupertino
          ? PlatformTestApp(
              platform: TargetPlatform.iOS,
              locale: locale,
              textScale: textScale,
              supportedLocales: ReadflexSupportedLocales.locales,
              localizationsDelegates: readflexLocalizationsDelegates,
              home: sheet,
            )
          : app(Scaffold(body: sheet)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseTarget(WidgetTester tester, String language) async {
    await tester.tap(targetMenu);
    await tester.pumpAndSettle();
    final nativeOption = find.widgetWithText(CupertinoListTile, language);
    if (nativeOption.evaluate().isNotEmpty) {
      await tester.ensureVisible(nativeOption);
    }
    await tester.tap(find.text(language).hitTestable().last);
    await tester.pumpAndSettle();
  }

  testWidgets('choosing the text language as the target sends no request '
      'and offers the definition of a word', (tester) async {
    final service = _RecordingService();
    await pumpSheet(tester, service);
    expect(find.text('сила'), findsOneWidget);
    expect(service.targets, ['ru']);

    await chooseTarget(tester, 'English');

    final l10n = l10nOf(tester);
    expect(service.targets, ['ru'], reason: 'English to English is not sent');
    expect(find.text('сила'), findsNothing, reason: 'no stale translation');
    expect(message, findsOneWidget);
    expect(find.text(l10n.translationSameLanguageTitle), findsOneWidget);
    expect(
      find.text(
        l10n.translationSameLanguageDefineBody(
          'English',
          l10n.dictionaryAction,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, l10n.dictionaryAction),
      findsOneWidget,
    );
    // The direction still names the detected source.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('translation-source-language')),
        matching: find.text('English'),
      ),
      findsOneWidget,
    );

    await chooseTarget(tester, 'Deutsch');
    expect(service.targets, ['ru', 'de']);
    expect(message, findsNothing);
    expect(find.text('Kraft'), findsOneWidget);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'Cupertino same-language recovery opens its native picker: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _RecordingService();
        await pumpSheet(
          tester,
          service,
          selection: _paragraph,
          cupertino: true,
          locale: locale,
          textScale: 2,
        );
        expect(service.targets, ['ru']);
        await chooseTarget(tester, 'English');
        final l10n = l10nOf(tester);
        expect(message, findsOneWidget);
        expect(service.targets, ['ru']);
        expect(find.byType(CupertinoPopupSurface), findsNothing);
        final recover = find.widgetWithText(
          AppButton,
          l10n.translationSelectLanguage,
        );
        await tester.ensureVisible(recover);
        await tester.tap(recover);
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoPopupSurface), findsOneWidget);
        expect(find.byType(MenuItemButton), findsNothing);
        final option = find.widgetWithText(CupertinoListTile, 'Deutsch');
        await tester.ensureVisible(option);
        expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(service.targets, ['ru', 'de']);
        expect(message, findsNothing);
        expect(find.text('Kraft'), findsOneWidget);
        expect(find.byType(CupertinoPopupSurface), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('longer text points to the target menu instead', (tester) async {
    final service = _RecordingService();
    await pumpSheet(tester, service, selection: _paragraph);
    await chooseTarget(tester, 'English');

    final l10n = l10nOf(tester);
    expect(
      find.text(l10n.translationSameLanguageBody('English')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, l10n.dictionaryAction),
      findsNothing,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.translationSelectLanguage),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский').hitTestable().last);
    await tester.pumpAndSettle();
    expect(service.targets, ['ru', 'ru']);
    expect(message, findsNothing);
  });

  testWidgets('without a dictionary a word also points to the target menu', (
    tester,
  ) async {
    final service = _RecordingService();
    await pumpSheet(tester, service, canDefine: false);
    await chooseTarget(tester, 'English');

    final l10n = l10nOf(tester);
    expect(
      find.widgetWithText(FilledButton, l10n.translationSelectLanguage),
      findsOneWidget,
    );
    expect(find.text(l10n.dictionaryAction), findsNothing);
  });

  testWidgets('a same-language answer from the provider shows the message', (
    tester,
  ) async {
    final service = _RecordingService(answerSameLanguage: 'ru');
    await pumpSheet(tester, service);

    final l10n = l10nOf(tester);
    expect(message, findsOneWidget);
    expect(
      find.text(
        l10n.translationSameLanguageDefineBody(
          'Русский',
          l10n.dictionaryAction,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('translation-source-language')),
        matching: find.text('Русский'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Define closes the sheet with the define outcome', (
    tester,
  ) async {
    final service = _RecordingService(answerSameLanguage: 'ru');
    final outcomes = <TranslateSheetOutcome?>[];
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => outcomes.add(
                await showTranslateSheet(
                  context,
                  selection: _word,
                  translationService: service,
                  preferencesService: preferences,
                  canDefine: true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, l10nOf(tester).dictionaryAction),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TranslateSheet), findsNothing);
    expect(outcomes, [TranslateSheetOutcome.define]);
  });

  group('TranslateAction', () {
    late BuildContext hostContext;

    Future<List<(BuildContext, TextSelectionContext)>> pumpAction(
      WidgetTester tester,
      _RecordingService service, {
      required bool withDictionary,
    }) async {
      final defined = <(BuildContext, TextSelectionContext)>[];
      final action = TranslateAction(
        translationService: service,
        preferencesService: preferences,
        onDefine: withDictionary
            ? (context, selection) async => defined.add((context, selection))
            : null,
      );
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return TextButton(
                  onPressed: () => action.onExecute(context, _word),
                  child: const Text('translate'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('translate'));
      await tester.pumpAndSettle();
      return defined;
    }

    testWidgets('Define runs the definition with the caller context', (
      tester,
    ) async {
      final service = _RecordingService(answerSameLanguage: 'ru');
      final defined = await pumpAction(tester, service, withDictionary: true);

      await tester.tap(
        find.widgetWithText(FilledButton, l10nOf(tester).dictionaryAction),
      );
      await tester.pumpAndSettle();

      expect(defined, hasLength(1));
      final (context, selection) = defined.single;
      expect(context, same(hostContext), reason: 'not the closed sheet');
      expect(context.mounted, isTrue);
      expect(selection, same(_word));
    });

    testWidgets('closing the sheet runs nothing', (tester) async {
      final service = _RecordingService(answerSameLanguage: 'ru');
      final defined = await pumpAction(tester, service, withDictionary: true);

      await tester.tap(
        find.byTooltip(l10nOf(tester).commonClose).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TranslateSheet), findsNothing);
      expect(defined, isEmpty);
    });

    testWidgets('without a dictionary the sheet offers no Define', (
      tester,
    ) async {
      final service = _RecordingService(answerSameLanguage: 'ru');
      await pumpAction(tester, service, withDictionary: false);

      final l10n = l10nOf(tester);
      expect(find.text(l10n.dictionaryAction), findsNothing);
      expect(
        find.widgetWithText(FilledButton, l10n.translationSelectLanguage),
        findsOneWidget,
      );
    });
  });
}

const _word = TextSelectionContext(
  selectedText: 'power',
  contextText: 'This power bank provides emergency power.',
  markedContextText: 'This [[power]] bank provides emergency power.',
  sourceId: 'source-1',
  sourceType: SourceType.book,
  sourceLanguageHint: 'en',
);

const _paragraph = TextSelectionContext(
  selectedText: 'The power failed. Everyone waited in the dark.',
  contextText: 'The power failed. Everyone waited in the dark.',
  sourceId: 'source-1',
  sourceType: SourceType.book,
  sourceLanguageHint: 'en',
);

/// Answers English text in any target, or reports that the text is already
/// in [answerSameLanguage].
class _RecordingService implements ContextualTranslationService {
  _RecordingService({this.answerSameLanguage});

  final String? answerSameLanguage;
  final targets = <String>[];

  static const _answers = {'ru': 'сила', 'de': 'Kraft'};

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    targets.add(request.targetLanguage);
    final same = answerSameLanguage;
    if (same != null) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.sameLanguage,
        'same',
        sourceLanguage: same,
        targetLanguage: request.targetLanguage,
      );
    }
    return ContextualTranslationResult(
      requestId: request.requestId,
      mode: request.mode,
      status: ContextualTranslationStatus.resolved,
      reliability: ContextualTranslationReliability.verified,
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      translation: ContextualTranslationText(
        contextualTranslation: _answers[request.targetLanguage] ?? 'power',
      ),
    );
  }

  @override
  void dispose() {}
}
