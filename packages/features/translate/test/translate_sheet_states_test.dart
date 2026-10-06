import 'dart:async';

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

  testWidgets('loading shows the shared spinner under the quoted phrase', (
    tester,
  ) async {
    final service = _GatedService();
    await _pumpSheet(tester, service: service, selection: _arabicSelection);

    final quote = find.byType(AppSourceQuote);
    expect(quote, findsOneWidget);
    expect(
      tester.widget<AppSourceQuote>(quote).textDirection,
      TextDirection.rtl,
    );
    final spinner = find.byType(CenteredCircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(
      tester
          .widget<Padding>(
            find.ancestor(of: spinner, matching: find.byType(Padding)).first,
          )
          .padding,
      const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    );
    expect(
      tester.getTopLeft(spinner).dy,
      greaterThan(tester.getBottomLeft(quote).dy),
    );

    service.resolve();
    await tester.pumpAndSettle();
    expect(find.byType(CenteredCircularProgressIndicator), findsNothing);
    expect(find.text('سيلا'), findsOneWidget);
  });

  testWidgets('offline model download runs as a busy status message', (
    tester,
  ) async {
    final service = _OfflineModelService(source: 'en', target: 'ru');
    await _pumpSheet(tester, service: service);

    final message = find.byType(AppStatusMessage);
    expect(message, findsOneWidget);
    expect(tester.widget<AppStatusMessage>(message).busy, isFalse);
    expect(find.text('Offline models required'), findsOneWidget);
    final l10n = tester.element(find.byType(TranslateSheet)).l10n;
    expect(
      find.text(l10n.translationOfflineModelBody('English', 'Русский')),
      findsOneWidget,
    );
    expect(find.text('?'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Download models'));
    await tester.pump();

    expect(tester.widget<AppStatusMessage>(message).busy, isTrue);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Downloading models'), findsOneWidget);
    expect(service.downloads, 1);

    service.resolve();
    await tester.pumpAndSettle();
    expect(find.byType(AppStatusMessage), findsNothing);
    expect(find.text('сила'), findsOneWidget);
  });

  testWidgets('unknown offline languages use the localized label', (
    tester,
  ) async {
    await _pumpSheet(tester, service: _OfflineModelService());
    final context = tester.element(find.byType(TranslateSheet));
    final l10n = context.l10n;
    expect(
      find.text(
        l10n.translationOfflineModelBody(
          l10n.translationUnknownLanguage,
          l10n.translationUnknownLanguage,
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('?'), findsNothing);
  });

  testWidgets('failure uses the shared status message with Retry', (
    tester,
  ) async {
    final service = _GatedService();
    await _pumpSheet(tester, service: service);
    service.fail();
    await tester.pumpAndSettle();
    expect(find.byType(AppStatusMessage), findsOneWidget);
    expect(find.byType(AppSourceQuote), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    expect(service.calls, 2);
    expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
    service.resolve();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'selected word is a selectable serif headline with a lexical row',
    (tester) async {
      await _pumpSheet(
        tester,
        locale: const Locale('ar'),
        service: _GatedService(
          analysis: const ContextualTranslationAnalysis(
            surfaceForm: 'power',
            pronunciation: '/ˈpaʊər/',
            partOfSpeech: 'noun',
          ),
        )..resolveImmediately = true,
      );
      final word = find.byKey(const ValueKey('translation-selected-fragment'));
      final theme = Theme.of(tester.element(word));
      expect(
        tester.widget<SelectableText>(word).style,
        theme.textTheme.headlineSmall!.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      );
      expect(
        theme.textTheme.headlineSmall!.fontFamily,
        AppTypography.fontFamilySerif,
      );
      expect(find.byType(AppLexicalMetadataRow), findsOneWidget);
      final ipa = find.text('/ˈpaʊər/');
      expect(Directionality.of(tester.element(ipa)), TextDirection.ltr);
      expect(
        tester.widget<Text>(ipa).style!.fontFamily,
        AppTypography.fontFamilyPhonetic,
      );
      final context = tester.element(find.byType(TranslateSheet));
      expect(find.text(context.l10n.translationPosNoun), findsOneWidget);
      expect(find.byType(AppSourceQuote), findsOneWidget);
    },
  );

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'details disclosure motion token, reduced motion: $reduceMotion',
      (tester) async {
        await _pumpSheet(
          tester,
          service: _GatedService(explanation: 'Lexical explanation')
            ..resolveImmediately = true,
          reduceMotion: reduceMotion,
        );
        final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
        expect(
          tile.expansionAnimationStyle!.duration,
          reduceMotion ? Duration.zero : AppMotion.short,
        );
        expect(
          tester
              .widget<AnimatedRotation>(find.byType(AnimatedRotation))
              .duration,
          reduceMotion ? Duration.zero : AppMotion.short,
        );
      },
    );
  }
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required ContextualTranslationService service,
  TextSelectionContext selection = _selection,
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
}) async {
  final preferences = await PreferencesService.create(
    supportedCodes: ReadflexSupportedLocales.codes,
  );
  addTearDown(preferences.dispose);
  await preferences.update(
    (prefs) => prefs.copyWith(translationTargetLanguageCode: 'ru'),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: TranslateSheet(
          selection: selection,
          translationService: service,
          preferencesService: preferences,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  contextText: 'This power bank provides emergency power.',
  markedContextText: 'This [[power]] bank provides emergency power.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _arabicSelection = TextSelectionContext(
  selectedText: 'الطاقة',
  contextText: 'توفر هذه البطارية الطاقة للأجهزة.',
  markedContextText: 'توفر هذه البطارية [[الطاقة]] للأجهزة.',
  sourceId: 'source-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'ar',
);

ContextualTranslationResult _result(
  ContextualTranslationRequest request, {
  ContextualTranslationAnalysis? analysis,
  String? explanation,
}) => ContextualTranslationResult(
  requestId: request.requestId,
  mode: request.mode,
  status: ContextualTranslationStatus.resolved,
  reliability: ContextualTranslationReliability.verified,
  detectedSourceLanguage: request.sourceLanguage == 'auto'
      ? 'en'
      : request.sourceLanguage,
  targetLanguage: request.targetLanguage,
  analysis: analysis,
  translation: ContextualTranslationText(
    contextualTranslation: request.sourceLanguageHint == 'ar' ? 'سيلا' : 'сила',
  ),
  explanation: explanation,
);

class _GatedService implements ContextualTranslationService {
  _GatedService({this.analysis, this.explanation});

  final ContextualTranslationAnalysis? analysis;
  final String? explanation;
  bool resolveImmediately = false;
  var calls = 0;
  Completer<ContextualTranslationResult>? _pending;
  ContextualTranslationRequest? _request;

  void resolve() => _pending!.complete(
    _result(_request!, analysis: analysis, explanation: explanation),
  );

  void fail() => _pending!.completeError(
    const ContextualTranslationException(
      ContextualTranslationFailureReason.network,
      'offline',
    ),
  );

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) async {
    calls++;
    _request = request;
    if (resolveImmediately) {
      return _result(request, analysis: analysis, explanation: explanation);
    }
    _pending = Completer<ContextualTranslationResult>();
    return _pending!.future;
  }

  @override
  void dispose() {}
}

class _OfflineModelService implements ContextualTranslationService {
  _OfflineModelService({this.source, this.target});

  final String? source;
  final String? target;
  var downloads = 0;
  Completer<ContextualTranslationResult>? _pending;
  ContextualTranslationRequest? _request;

  void resolve() => _pending!.complete(_result(_request!));

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
    Future<void>? abortTrigger,
  }) {
    if (!allowOfflineModelDownload) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.offlineModelRequired,
        'models required',
        sourceLanguage: source,
        targetLanguage: target,
      );
    }
    downloads++;
    _request = request;
    _pending = Completer<ContextualTranslationResult>();
    return _pending!.future;
  }

  @override
  void dispose() {}
}
