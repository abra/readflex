import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

void main() {
  testWidgets(
    'loading and failure quote the Arabic phrase in its own direction',
    (tester) async {
      final service = _GatedDictionaryService();
      await _pumpSheet(tester, service: service, selection: _arabicSelection);

      final quote = find.byKey(const ValueKey('dictionary-source-quote'));
      expect(
        tester.widget<AppSourceQuote>(quote).textDirection,
        TextDirection.rtl,
      );
      final phrase = find.byKey(const ValueKey('dictionary-source-phrase'));
      expect(Directionality.of(tester.element(phrase)), TextDirection.rtl);
      expect(
        tester.widget<Text>(phrase).style,
        Theme.of(tester.element(phrase)).textTheme.bodyMedium!.copyWith(
          color: Theme.of(tester.element(phrase)).colorScheme.onSurface,
        ),
      );
      final spinner = find.byType(CenteredCircularProgressIndicator);
      expect(spinner, findsOneWidget);
      final spinnerPadding = tester.widget<Padding>(
        find.ancestor(of: spinner, matching: find.byType(Padding)).first,
      );
      expect(
        spinnerPadding.padding,
        const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      );
      final loadingHeight = tester.getSize(find.byType(DictionarySheet)).height;

      service.fail();
      await tester.pumpAndSettle();

      expect(find.byType(AppStatusMessage), findsOneWidget);
      expect(find.text('Definition unavailable'), findsOneWidget);
      expect(find.byType(CenteredCircularProgressIndicator), findsNothing);
      expect(
        tester.widget<AppSourceQuote>(quote).textDirection,
        TextDirection.rtl,
      );
      expect(
        tester.getSize(find.byType(DictionarySheet)).height,
        greaterThanOrEqualTo(loadingHeight),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      expect(service.calls, 2);
      expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
      service.fail();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('not found keeps the quoted phrase and shows the status', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      service: _ResultDictionaryService(
        status: DictionaryLookupStatus.notFound,
        entries: const [],
      ),
    );
    expect(find.byType(AppSourceQuote), findsOneWidget);
    expect(find.byType(AppStatusMessage), findsOneWidget);
    expect(find.text('No definition found'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('headword is a selectable serif headline with header semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpSheet(tester);
      final lemma = find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'power',
      );
      final theme = Theme.of(tester.element(lemma));
      expect(
        tester.widget<SelectableText>(lemma).style,
        theme.textTheme.headlineSmall,
      );
      expect(
        theme.textTheme.headlineSmall!.fontFamily,
        AppTypography.fontFamilySerif,
      );
      expect(
        find.ancestor(
          of: lemma,
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.header == true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(AppSourceQuote), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('metadata row keeps IPA left-to-right in an Arabic interface', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      locale: const Locale('ar'),
      service: _ResultDictionaryService(
        entries: const [
          DictionaryLexicalEntry(
            lemma: 'power',
            reading: 'pow-er',
            pronunciation: '/ˈpaʊər/',
            partOfSpeech: 'noun',
            definitions: [DictionaryDefinition(text: 'Energy for devices.')],
          ),
        ],
      ),
    );
    expect(find.byType(AppLexicalMetadataRow), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    final ipa = find.text('/ˈpaʊər/');
    expect(Directionality.of(tester.element(ipa)), TextDirection.ltr);
    expect(
      tester.widget<Text>(ipa).style!.fontFamily,
      AppTypography.fontFamilyPhonetic,
    );
    expect(find.text('pow-er'), findsOneWidget);
    // The backend's raw tag is shown; there is no dictionary POS catalog.
    expect(find.text('noun'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('pow-er')).dy,
      lessThan(tester.getTopLeft(find.text('Energy for devices.')).dy),
    );
  });

  testWidgets('definition numbers are localized and scale with text', (
    tester,
  ) async {
    await _pumpSheet(tester, locale: const Locale('ru'));
    final context = tester.element(find.byType(DictionarySheet));
    final number = find.text(context.l10n.dictionaryDefinitionNumber(1));
    expect(number, findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(tester.widget<Text>(number).style!.fontFeatures, const [
      FontFeature.tabularFigures(),
    ]);
    expect(
      tester
          .getSize(
            find.ancestor(of: number, matching: find.byType(SizedBox)).first,
          )
          .width,
      AppSpacing.xl + AppSpacing.xs,
    );
    final definition = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText && widget.data == 'Energy for devices.',
    );
    final theme = Theme.of(tester.element(definition));
    expect(
      tester.widget<SelectableText>(definition).style,
      theme.textTheme.bodyLarge,
    );
    expect(
      tester.widget<Text>(find.text('Devices need power.')).style,
      theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );

    await _pumpSheet(
      tester,
      locale: const Locale('ru'),
      textScaler: const TextScaler.linear(2),
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(of: find.text('1.'), matching: find.byType(SizedBox))
                .first,
          )
          .width,
      2 * (AppSpacing.xl + AppSpacing.xs),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  DictionaryLookupService? service,
  TextSelectionContext selection = _selection,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      supportedLocales: ReadflexSupportedLocales.locales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: DictionarySheet(
          selection: selection,
          dictionaryService: service ?? _ResultDictionaryService(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _arabicSelection = TextSelectionContext(
  selectedText: 'الطاقة',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'ar',
);

class _ResultDictionaryService implements DictionaryLookupService {
  _ResultDictionaryService({
    this.status = DictionaryLookupStatus.found,
    this.entries = const [
      DictionaryLexicalEntry(
        lemma: 'power',
        partOfSpeech: 'noun',
        definitions: [
          DictionaryDefinition(
            text: 'Energy for devices.',
            examples: ['Devices need power.'],
          ),
        ],
      ),
    ],
  });

  final DictionaryLookupStatus status;
  final List<DictionaryLexicalEntry> entries;

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) async {
    return DictionaryLookupResult(
      requestId: request.requestId,
      status: status,
      term: request.term,
      language: 'en',
      entries: entries,
    );
  }

  @override
  void dispose() {}
}

class _GatedDictionaryService implements DictionaryLookupService {
  var calls = 0;
  Completer<DictionaryLookupResult>? _pending;

  void fail() => _pending!.completeError(
    const DictionaryLookupException(
      DictionaryLookupFailureReason.network,
      'offline',
    ),
  );

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) {
    calls++;
    _pending = Completer<DictionaryLookupResult>();
    return _pending!.future;
  }

  @override
  void dispose() {}
}
