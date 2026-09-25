import 'package:component_library/component_library.dart';
import 'package:dictionary/dictionary.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

void main() {
  testWidgets('a resolved term appears once without a preview card', (
    tester,
  ) async {
    await _pumpDictionarySheet(tester);
    expect(find.text('power'), findsOneWidget);
    expect(find.byType(SelectionPreviewCard), findsNothing);
    final lemma = find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == 'power',
    );
    expect(
      tester.widget<SelectableText>(lemma).style,
      Theme.of(tester.element(lemma)).textTheme.titleLarge,
    );
    expect(tester.getSize(find.byType(DictionarySheet)).height, lessThan(400));
  });

  testWidgets(
    'selected form and contextual expression retain separate copies',
    (tester) async {
      final service = _EntryDictionaryService(entries: _expressionEntries);
      final copied = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pumpDictionarySheet(
        tester,
        service: service,
        selection: _inflectedSelection,
      );
      expect(find.text('shutting'), findsOneWidget);
      expect(find.text('shut'), findsOneWidget);
      expect(find.text('shut off'), findsOneWidget);
      expect(find.text('In this context'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('shut')).dy,
        lessThan(tester.getTopLeft(find.text('shut off')).dy),
      );
      expect(find.byType(SelectionPreviewCard), findsNothing);
      final copyButtons = find.byType(AppCopyButton);
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(copyButtons.at(i));
        await tester.tap(copyButtons.at(i));
        await tester.pump();
      }
      expect(copied, ['shut\n1. To close.', 'shut off\n1. To stop a supply.']);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final locale in ReadflexSupportedLocales.locales) {
    testWidgets('dictionary remains usable in $locale with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final service = _EntryDictionaryService(entries: _expressionEntries);
        await _pumpDictionarySheet(
          tester,
          locale: locale,
          textScaler: const TextScaler.linear(2),
          selection: _inflectedSelection,
          service: service,
        );
        final context = tester.element(find.byType(DictionarySheet));
        expect(find.text(context.l10n.dictionaryTitle).hitTestable(), findsOne);
        expect(find.text('shutting'), findsOne);
        for (final copy in find.byType(AppCopyButton).evaluate()) {
          final finder = find.byWidget(copy.widget);
          await tester.ensureVisible(finder);
          expect(finder.hitTestable(), findsOne);
          expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
        }
        await tester.ensureVisible(find.text('To stop a supply.'));
        expect(find.text('To stop a supply.').hitTestable(), findsOne);
        expect(tester.takeException(), isNull);
        expect(service.calls, 1);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('dictionary content follows its own writing direction', (
    tester,
  ) async {
    await _pumpDictionarySheet(tester, locale: const Locale('ar'));
    final definition = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText && widget.data == 'Energy for devices.',
    );
    expect(Directionality.of(tester.element(definition)), TextDirection.ltr);
  });

  testWidgets('Arabic definitions and examples keep RTL in an English UI', (
    tester,
  ) async {
    await _pumpDictionarySheet(
      tester,
      selection: const TextSelectionContext(
        selectedText: 'الطاقة',
        sourceId: 'article-1',
        sourceType: SourceType.article,
      ),
      service: _EntryDictionaryService(
        entries: const [
          DictionaryLexicalEntry(
            lemma: 'الطاقة',
            partOfSpeech: 'اسم',
            definitions: [
              DictionaryDefinition(
                text: 'القدرة على أداء العمل.',
                examples: ['تحتاج الأجهزة إلى الطاقة.'],
              ),
            ],
          ),
        ],
      ),
    );
    final definition = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText && widget.data == 'القدرة على أداء العمل.',
    );
    expect(Directionality.of(tester.element(definition)), TextDirection.rtl);
    expect(
      tester.widget<Text>(find.text('تحتاج الأجهزة إلى الطاقة.')).textDirection,
      TextDirection.rtl,
    );
    expect(find.text('الطاقة'), findsOneWidget);
    expect(find.byTooltip('Copy').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'copy includes definitions without another lookup at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final copied = <String>[];
      final service = _RecordingDictionaryService();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: DictionarySheet(
              selection: _selection,
              dictionaryService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(copied, [
        ['power', for (var i = 1; i <= 20; i++) '$i. Definition $i'].join('\n'),
      ]);
      expect(service.calls, 1);
      expect(find.byTooltip('Copied'), findsOneWidget);
      await tester.ensureVisible(find.text('Definition 20'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('long dictionary result is constrained and scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: const Scaffold(
          body: DictionarySheet(
            selection: _selection,
            dictionaryService: _LongDictionaryService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    expect(tester.getSize(scrollView).height, closeTo(408, 0.001));
    expect(find.text('Definition 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDictionarySheet(
  WidgetTester tester, {
  DictionaryLookupService? service,
  TextSelectionContext selection = _selection,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  late BuildContext sheetContext;
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
      home: Builder(
        builder: (context) {
          sheetContext = context;
          return const Scaffold();
        },
      ),
    ),
  );
  showDictionarySheet(
    sheetContext,
    selection: selection,
    dictionaryService: service ?? _EntryDictionaryService(),
  );
  await tester.pumpAndSettle();
}

const _inflectedSelection = TextSelectionContext(
  selectedText: 'shutting',
  contextText: 'The device saves power by shutting off its display.',
  markedContextText: 'The device saves power by [[shutting]] off its display.',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

const _expressionEntries = [
  DictionaryLexicalEntry(
    lemma: 'shut',
    partOfSpeech: 'verb',
    definitions: [DictionaryDefinition(text: 'To close.')],
  ),
  DictionaryLexicalEntry(
    lemma: 'shut off',
    partOfSpeech: 'phrasal verb',
    definitions: [DictionaryDefinition(text: 'To stop a supply.')],
  ),
];

class _EntryDictionaryService implements DictionaryLookupService {
  _EntryDictionaryService({
    this.entries = const [
      DictionaryLexicalEntry(
        lemma: 'power',
        partOfSpeech: 'noun',
        definitions: [DictionaryDefinition(text: 'Energy for devices.')],
      ),
    ],
  });

  final List<DictionaryLexicalEntry> entries;
  var calls = 0;

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) async {
    calls++;
    return DictionaryLookupResult(
      requestId: request.requestId,
      status: DictionaryLookupStatus.found,
      term: request.term,
      language: 'en',
      entries: entries,
    );
  }

  @override
  void dispose() {}
}

const _selection = TextSelectionContext(
  selectedText: 'power',
  sourceId: 'article-1',
  sourceType: SourceType.article,
  sourceLanguageHint: 'en',
);

class _LongDictionaryService implements DictionaryLookupService {
  const _LongDictionaryService();

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) async {
    return DictionaryLookupResult(
      requestId: request.requestId,
      status: DictionaryLookupStatus.found,
      term: request.term,
      language: 'en',
      entries: [
        DictionaryLexicalEntry(
          lemma: 'power',
          partOfSpeech: 'noun',
          definitions: List.generate(
            20,
            (index) => DictionaryDefinition(
              text: 'Definition ${index + 1}',
              examples: ['Example ${index + 1}'],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {}
}

class _RecordingDictionaryService extends _LongDictionaryService {
  var calls = 0;

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) {
    calls++;
    return super.lookup(request);
  }
}
