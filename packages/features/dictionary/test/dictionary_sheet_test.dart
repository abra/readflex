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
      Theme.of(tester.element(lemma)).textTheme.headlineSmall,
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
        final close = find.byTooltip(context.l10n.commonClose);
        final width = tester.getSize(find.byType(DictionarySheet)).width;
        // Copy trails the English lemma: beside Close in an LTR interface,
        // on the opposite gutter in an RTL one.
        final copyCenter =
            Directionality.of(tester.element(close)) == TextDirection.ltr
            ? tester.getCenter(close).dx
            : width - tester.getCenter(close).dx;
        for (final copy in find.byType(AppCopyButton).evaluate()) {
          final finder = find.byWidget(copy.widget);
          await tester.ensureVisible(finder);
          expect(finder.hitTestable(), findsOne);
          expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
          expect(tester.getCenter(finder).dx, copyCenter);
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
    expect(tester.getSize(scrollView).height, closeTo(600 * .72, 0.001));
    final header = tester.getRect(find.byType(BottomSheetHeader));
    await tester.ensureVisible(find.text('Definition 20'));
    await tester.pumpAndSettle();
    expect(find.text('Definition 20').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheetHeader)), header);
    expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('layout', () {
    Finder lemma(String text) => find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == text,
    );

    testWidgets('the expression comes first, the word meaning after it', (
      tester,
    ) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(entries: _expressionEntries),
        selection: _inflectedSelection,
      );
      final order = [
        lemma('shut'),
        find.text('In this context'),
        lemma('shut off'),
        find.text('To stop a supply.'),
        find.text('Word meaning'),
        find.text('To close.'),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          tester.getTopLeft(order[i - 1]).dy,
          lessThan(tester.getTopLeft(order[i]).dy),
          reason: '$i',
        );
      }
      final theme = Theme.of(tester.element(lemma('shut')));
      expect(
        tester.widget<SelectableText>(lemma('shut')).style,
        theme.textTheme.headlineSmall,
      );
      expect(
        tester.widget<SelectableText>(lemma('shut off')).style,
        theme.textTheme.titleMedium!.copyWith(
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      );
      // Captions sit 8dp above their content.
      expect(
        tester.getRect(lemma('shut off')).top -
            tester.getRect(find.text('In this context')).bottom,
        AppSpacing.sm,
      );
      expect(
        tester.getRect(find.text('To close.')).top -
            tester.getRect(find.text('Word meaning')).bottom,
        AppSpacing.sm,
      );
      expect(find.byType(Divider), findsNothing);
    });

    Rect outline(WidgetTester tester, int index) => tester.getRect(
      find
          .descendant(
            of: find.byType(AppSheetSection).at(index),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  (widget.decoration as BoxDecoration?)?.border != null,
            ),
          )
          .first,
    );
    // A definition row, number column included.
    Finder definitionRow(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(Row)).first;

    testWidgets('the expression and the word meaning are outlined sections', (
      tester,
    ) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(entries: _expressionEntries),
        selection: _inflectedSelection,
      );
      final sections = find.byType(AppSheetSection);
      expect(sections, findsNWidgets(2));
      for (final (index, content) in [(0, 'shut off'), (1, 'To close.')]) {
        expect(
          find.descendant(of: sections.at(index), matching: find.text(content)),
          findsOneWidget,
        );
      }
      // The headword stays above the sections.
      expect(
        find.descendant(of: sections.first, matching: lemma('shut')),
        findsNothing,
      );
    });

    testWidgets('a single entry has one untitled section', (tester) async {
      await _pumpDictionarySheet(tester);
      expect(find.byType(AppSheetSection), findsOneWidget);
      expect(
        tester.widget<AppSheetSection>(find.byType(AppSheetSection)).title,
        isNull,
      );
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('sections keep their spacing at ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(390, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpDictionarySheet(
          tester,
          textScaler: TextScaler.linear(scale),
          service: _EntryDictionaryService(entries: _expressionEntries),
          selection: _inflectedSelection,
        );
        final metadata = find.byType(AppLexicalMetadataRow);
        final first = outline(tester, 0);
        final second = outline(tester, 1);
        expect(
          first.top - tester.getRect(metadata.first).bottom,
          AppSpacing.lg,
        );
        expect(second.top - first.bottom, AppSpacing.md);
        expect(
          tester.getRect(find.text('In this context')).top - first.top,
          AppSpacing.md,
        );
        expect(
          tester.getRect(definitionRow('To stop a supply.')).top -
              tester.getRect(metadata.at(1)).bottom,
          AppSpacing.md,
        );
        expect(
          first.bottom -
              tester.getRect(definitionRow('To stop a supply.')).bottom,
          AppSpacing.md,
        );
        expect(
          tester.getRect(find.text('Word meaning')).top - second.top,
          AppSpacing.md,
        );
        expect(
          second.bottom - tester.getRect(definitionRow('To close.')).bottom,
          AppSpacing.md,
        );
      });
    }

    testWidgets('an entry without definitions keeps 12dp below its lemma', (
      tester,
    ) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(
          entries: const [
            DictionaryLexicalEntry(
              lemma: 'shut',
              definitions: [DictionaryDefinition(text: 'To close.')],
            ),
            DictionaryLexicalEntry(
              lemma: 'shut off',
              partOfSpeech: 'verb',
              definitions: [],
            ),
          ],
        ),
        selection: _inflectedSelection,
      );
      final metadata = find.byType(AppLexicalMetadataRow).last;
      expect(
        outline(tester, 0).bottom - tester.getRect(metadata).bottom,
        AppSpacing.md,
      );
    });

    testWidgets('Copy reaches the outline of its section', (tester) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(entries: _expressionEntries),
        selection: _inflectedSelection,
      );
      final copy = tester.getRect(find.byType(AppCopyButton).at(1));
      expect(copy.right, moreOrLessEquals(outline(tester, 0).right));
    });

    testWidgets('a single entry has no captions', (tester) async {
      await _pumpDictionarySheet(tester);
      expect(find.text('In this context'), findsNothing);
      expect(find.text('Word meaning'), findsNothing);
    });

    testWidgets('further entries follow the word meaning as small headings', (
      tester,
    ) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(
          entries: const [
            ..._expressionEntries,
            DictionaryLexicalEntry(
              lemma: 'shutter',
              partOfSpeech: 'noun',
              definitions: [DictionaryDefinition(text: 'A window cover.')],
            ),
          ],
        ),
        selection: _inflectedSelection,
      );
      await tester.ensureVisible(lemma('shutter'));
      expect(
        tester.getTopLeft(find.text('To close.')).dy,
        lessThan(tester.getTopLeft(lemma('shutter')).dy),
      );
      final theme = Theme.of(tester.element(lemma('shutter')));
      expect(
        tester.widget<SelectableText>(lemma('shutter')).style,
        theme.textTheme.titleMedium!.copyWith(
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      );
      expect(find.byType(AppCopyButton), findsNWidgets(3));
    });

    testWidgets('each Copy is centered on its lemma line', (tester) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(entries: _expressionEntries),
        selection: _inflectedSelection,
      );
      final copies = find.byType(AppCopyButton);
      for (final (index, text) in ['shut', 'shut off'].indexed) {
        final style = tester.widget<SelectableText>(lemma(text)).style!;
        final line = style.fontSize! * style.height!;
        expect(
          tester.getCenter(copies.at(index)).dy,
          moreOrLessEquals(tester.getRect(lemma(text)).top + line / 2),
          reason: text,
        );
      }
    });

    testWidgets('in an Arabic UI the English entry keeps its edge, captions '
        'theirs', (tester) async {
      await _pumpDictionarySheet(
        tester,
        locale: const Locale('ar'),
        service: _EntryDictionaryService(
          entries: const [
            DictionaryLexicalEntry(
              lemma: 'shut',
              pronunciation: '/ʃʌt/',
              partOfSpeech: 'verb',
              definitions: [DictionaryDefinition(text: 'To close.')],
            ),
            DictionaryLexicalEntry(
              lemma: 'shut off',
              partOfSpeech: 'phrasal verb',
              definitions: [DictionaryDefinition(text: 'To stop a supply.')],
            ),
          ],
        ),
        selection: _inflectedSelection,
      );
      final context = tester.element(find.byType(DictionarySheet));
      final sheet = tester.getRect(find.byType(DictionarySheet));
      for (final caption in [
        context.l10n.dictionaryInContext,
        context.l10n.dictionaryWordMeaning,
      ]) {
        await tester.ensureVisible(find.text(caption));
        expect(
          sheet.right - tester.getRect(find.text(caption)).right,
          AppSpacing.xl,
          reason: caption,
        );
      }
      await tester.ensureVisible(lemma('shut'));
      final headword = tester.getRect(lemma('shut'));
      // The heading line starts with the selected form, `shutting -> shut`.
      final form = tester.getRect(find.text('shutting'));
      expect(form.left - sheet.left, AppSpacing.xl);
      expect(headword.left, greaterThan(form.right));
      // The metadata row starts under the heading, not on the UI's edge.
      expect(tester.getRect(find.text('/ʃʌt/')).left, form.left);
      final copy = tester.getRect(find.byType(AppCopyButton).first);
      expect(copy.left, greaterThan(headword.right));
    });

    testWidgets('a long lemma shrinks at large text instead of breaking', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Test glyphs are squares: at 2x the word does not fit at the heading
      // size and fits at a smaller one.
      const word = 'fortune';
      await _pumpDictionarySheet(
        tester,
        textScaler: const TextScaler.linear(2),
        selection: const TextSelectionContext(
          selectedText: word,
          sourceId: 'article-1',
          sourceType: SourceType.article,
        ),
        service: _EntryDictionaryService(
          entries: const [
            DictionaryLexicalEntry(
              lemma: word,
              definitions: [DictionaryDefinition(text: 'Wealth.')],
            ),
          ],
        ),
      );
      final theme = Theme.of(tester.element(lemma(word)));
      final style = tester.widget<SelectableText>(lemma(word)).style!;
      expect(
        style.fontSize,
        lessThan(theme.textTheme.headlineSmall!.fontSize!),
      );
      expect(
        style.fontSize,
        greaterThanOrEqualTo(theme.textTheme.bodyMedium!.fontSize!),
      );
      expect(
        tester.getSize(lemma(word)).height,
        closeTo(2 * style.fontSize! * style.height!, 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a found term without entries reads as not found', (
      tester,
    ) async {
      await _pumpDictionarySheet(
        tester,
        service: _EntryDictionaryService(entries: const []),
      );
      final context = tester.element(find.byType(DictionarySheet));
      expect(find.text(context.l10n.dictionaryNotFoundTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
